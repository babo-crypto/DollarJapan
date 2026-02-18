"""
Label Generator Module for TrendAI v10
=======================================

Generates binary labels for continuation prediction:
- Label = 1 if price moves >= 30 pips in trade direction within next 10 candles
- Label = 0 otherwise

Separate labels for bullish and bearish scenarios.

Author: TrendAI Development Team
Version: 10.0
"""

import pandas as pd
import numpy as np
from typing import Tuple
import warnings
warnings.filterwarnings('ignore')


class LabelGenerator:
    """
    Generate binary continuation labels for ML training.
    """
    
    def __init__(self, continuation_pips: float = 30.0, lookforward_candles: int = 10):
        """
        Initialize label generator.
        
        Args:
            continuation_pips: Minimum pip movement to consider continuation
            lookforward_candles: Number of candles to look forward for continuation
        """
        self.continuation_pips = continuation_pips
        self.lookforward_candles = lookforward_candles
        
        # For USDJPY, 1 pip = 0.01 (assuming 3 decimal places)
        # Adjust based on your broker's pip definition
        self.pip_value = 0.01
    
    def calculate_future_move(self, df: pd.DataFrame, direction: str = 'both') -> pd.Series:
        """
        Calculate maximum favorable move within lookforward window.
        
        Args:
            df: DataFrame with OHLC data
            direction: 'bullish', 'bearish', or 'both'
            
        Returns:
            Series with maximum favorable move in pips
        """
        max_move = pd.Series(index=df.index, dtype=float)
        
        for i in range(len(df) - self.lookforward_candles):
            current_close = df.iloc[i]['close']
            
            # Get future window
            future_window = df.iloc[i+1:i+1+self.lookforward_candles]
            
            if direction == 'bullish' or direction == 'both':
                # Maximum upward move
                max_high = future_window['high'].max()
                upward_move = (max_high - current_close) / self.pip_value
                max_move.iloc[i] = upward_move
            
            if direction == 'bearish':
                # Maximum downward move
                min_low = future_window['low'].min()
                downward_move = (current_close - min_low) / self.pip_value
                max_move.iloc[i] = downward_move
        
        return max_move
    
    def generate_bullish_labels(self, df: pd.DataFrame) -> pd.Series:
        """
        Generate labels for bullish continuation.
        
        Args:
            df: DataFrame with OHLC data
            
        Returns:
            Series with binary labels (1 = continuation, 0 = no continuation)
        """
        future_move = self.calculate_future_move(df, direction='bullish')
        labels = (future_move >= self.continuation_pips).astype(int)
        
        return labels
    
    def generate_bearish_labels(self, df: pd.DataFrame) -> pd.Series:
        """
        Generate labels for bearish continuation.
        
        Args:
            df: DataFrame with OHLC data
            
        Returns:
            Series with binary labels (1 = continuation, 0 = no continuation)
        """
        future_move = self.calculate_future_move(df, direction='bearish')
        labels = (future_move >= self.continuation_pips).astype(int)
        
        return labels
    
    def generate_directional_labels(self, df: pd.DataFrame, 
                                   price_kumo_distance: pd.Series) -> pd.Series:
        """
        Generate labels based on current directional bias.
        
        For bullish bias (price above cloud): check bullish continuation
        For bearish bias (price below cloud): check bearish continuation
        
        Args:
            df: DataFrame with OHLC data
            price_kumo_distance: Series indicating position relative to cloud
            
        Returns:
            Series with binary labels
        """
        bullish_labels = self.generate_bullish_labels(df)
        bearish_labels = self.generate_bearish_labels(df)
        
        # Combine based on directional bias
        labels = pd.Series(index=df.index, dtype=int)
        
        # Use bullish labels where price is above cloud
        bullish_mask = price_kumo_distance > 0.1
        labels[bullish_mask] = bullish_labels[bullish_mask]
        
        # Use bearish labels where price is below cloud
        bearish_mask = price_kumo_distance < -0.1
        labels[bearish_mask] = bearish_labels[bearish_mask]
        
        # Neutral/inside cloud: no label (will be filtered out)
        neutral_mask = (price_kumo_distance >= -0.1) & (price_kumo_distance <= 0.1)
        labels[neutral_mask] = -1  # Mark as invalid
        
        return labels
    
    def calculate_risk_reward_ratio(self, df: pd.DataFrame, labels: pd.Series,
                                   atr: pd.Series, sl_multiplier: float = 1.5) -> pd.Series:
        """
        Calculate realized risk-reward ratio for each trade.
        
        Args:
            df: DataFrame with OHLC data
            labels: Binary labels
            atr: ATR series
            sl_multiplier: Stop loss multiplier for ATR
            
        Returns:
            Series with risk-reward ratios
        """
        rr_ratio = pd.Series(index=df.index, dtype=float)
        
        for i in range(len(df) - self.lookforward_candles):
            current_close = df.iloc[i]['close']
            current_atr = atr.iloc[i]
            
            # Get future window
            future_window = df.iloc[i+1:i+1+self.lookforward_candles]
            
            # Calculate potential reward
            max_favorable = future_window['high'].max() - current_close
            
            # Calculate stop loss
            stop_loss = current_atr * sl_multiplier
            
            # Calculate R:R ratio
            if stop_loss > 0:
                rr_ratio.iloc[i] = max_favorable / stop_loss
            else:
                rr_ratio.iloc[i] = 0
        
        return rr_ratio
    
    def generate_labels_with_metadata(self, df: pd.DataFrame,
                                      price_kumo_distance: pd.Series,
                                      atr: pd.Series) -> pd.DataFrame:
        """
        Generate comprehensive label dataset with metadata.
        
        Args:
            df: DataFrame with OHLC data
            price_kumo_distance: Series indicating position relative to cloud
            atr: ATR series
            
        Returns:
            DataFrame with labels and metadata
        """
        # Generate directional labels
        labels = self.generate_directional_labels(df, price_kumo_distance)
        
        # Calculate metadata
        bullish_move = self.calculate_future_move(df, direction='bullish')
        bearish_move = self.calculate_future_move(df, direction='bearish')
        rr_ratio = self.calculate_risk_reward_ratio(df, labels, atr)
        
        # Create result DataFrame
        result = pd.DataFrame({
            'label': labels,
            'bullish_move_pips': bullish_move,
            'bearish_move_pips': bearish_move,
            'risk_reward_ratio': rr_ratio,
            'is_valid': labels >= 0
        }, index=df.index)
        
        return result
    
    def get_label_statistics(self, labels: pd.Series) -> dict:
        """
        Get statistics about generated labels.
        
        Args:
            labels: Series with binary labels
            
        Returns:
            Dictionary with label statistics
        """
        valid_labels = labels[labels >= 0]
        
        if len(valid_labels) == 0:
            return {
                'total_samples': 0,
                'positive_samples': 0,
                'negative_samples': 0,
                'positive_rate': 0.0,
                'class_balance': 0.0
            }
        
        total = len(valid_labels)
        positive = (valid_labels == 1).sum()
        negative = (valid_labels == 0).sum()
        
        return {
            'total_samples': total,
            'positive_samples': positive,
            'negative_samples': negative,
            'positive_rate': positive / total if total > 0 else 0.0,
            'class_balance': min(positive, negative) / max(positive, negative) if max(positive, negative) > 0 else 0.0
        }


def main():
    """
    Example usage and testing.
    """
    print("=" * 60)
    print("TrendAI v10 Label Generator Module")
    print("=" * 60)
    
    # Create sample data for testing
    dates = pd.date_range('2024-01-01', periods=1000, freq='15T')
    np.random.seed(42)
    
    # Simulate USDJPY price movement
    base_price = 150.0
    price_changes = np.cumsum(np.random.randn(1000) * 0.01)
    
    df = pd.DataFrame({
        'timestamp': dates,
        'open': base_price + price_changes,
        'high': base_price + price_changes + np.abs(np.random.randn(1000) * 0.02),
        'low': base_price + price_changes - np.abs(np.random.randn(1000) * 0.02),
        'close': base_price + price_changes,
        'tick_volume': np.random.randint(100, 1000, 1000)
    })
    
    # Set index
    df = df.set_index('timestamp')
    
    # Create mock features
    price_kumo_distance = pd.Series(np.random.randn(1000), index=df.index)
    atr = pd.Series(np.abs(np.random.randn(1000) * 0.05), index=df.index)
    
    # Initialize label generator
    lg = LabelGenerator(continuation_pips=30.0, lookforward_candles=10)
    
    print(f"\nConfiguration:")
    print(f"  Continuation threshold: {lg.continuation_pips} pips")
    print(f"  Lookforward window: {lg.lookforward_candles} candles")
    print(f"  Pip value: {lg.pip_value}")
    
    # Generate labels
    print("\nGenerating labels...")
    
    bullish_labels = lg.generate_bullish_labels(df)
    bearish_labels = lg.generate_bearish_labels(df)
    directional_labels = lg.generate_directional_labels(df, price_kumo_distance)
    
    print("✓ Labels generated successfully")
    
    # Get statistics
    print("\nBullish continuation statistics:")
    bullish_stats = lg.get_label_statistics(bullish_labels)
    for key, value in bullish_stats.items():
        print(f"  {key}: {value}")
    
    print("\nBearish continuation statistics:")
    bearish_stats = lg.get_label_statistics(bearish_labels)
    for key, value in bearish_stats.items():
        print(f"  {key}: {value}")
    
    print("\nDirectional label statistics:")
    directional_stats = lg.get_label_statistics(directional_labels)
    for key, value in directional_stats.items():
        print(f"  {key}: {value}")
    
    # Generate full label dataset with metadata
    print("\nGenerating comprehensive label dataset...")
    label_data = lg.generate_labels_with_metadata(df, price_kumo_distance, atr)
    
    print(f"✓ Complete label dataset created")
    print(f"  Shape: {label_data.shape}")
    print(f"  Columns: {list(label_data.columns)}")
    
    print("\nSample label data (first 5 rows):")
    print(label_data.head())
    
    print("\n" + "=" * 60)
    print("Label generator module ready for production use")
    print("=" * 60)


if __name__ == "__main__":
    main()
