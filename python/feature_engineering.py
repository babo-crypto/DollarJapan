"""
Feature Engineering Module for TrendAI v10
==========================================

This module mirrors the exact feature calculations from MQL5's feature_builder.mqh
to ensure consistency between training and inference.

Features include:
- Ichimoku indicators (Tenkan slope, Kijun slope, cloud thickness, price-kumo distance, Chikou position)
- Volatility measures (ATR normalized)
- Trend strength (ADX)
- Volume analysis (tick volume spike ratio)
- Session encoding (broker hour, session ID)
- Market conditions (spread, candle compression)
- Derived features (momentum strength, relative kumo strength)
- Market regime detection (v11)

Author: TrendAI Development Team
Version: 11.0
"""

import pandas as pd
import numpy as np
from typing import Dict, Tuple
import warnings
warnings.filterwarnings('ignore')

# Feature versioning (v11)
FEATURE_VERSION = "1.0.0"
FEATURE_LIST_V1 = [
    'tenkan_slope',
    'kijun_slope',
    'cloud_thickness',
    'price_kumo_distance',
    'chikou_relative_position',
    'atr_normalized',
    'adx',
    'tick_volume_spike',
    'broker_hour',
    'session_id',
    'spread',
    'candle_compression',
    'momentum_strength',  # Derived: tenkan_slope * ADX
    'relative_kumo_strength',  # Derived: cloud_thickness / ATR
    'regime_flag'  # NEW (v11): market regime detection
]


class FeatureEngineer:
    """
    Feature engineering class that mirrors MQL5 feature calculations.
    """
    
    def __init__(self):
        """Initialize feature engineer with default parameters."""
        self.tenkan_period = 9
        self.kijun_period = 26
        self.senkou_span_b_period = 52
        self.atr_period = 14
        self.adx_period = 14
        self.feature_names = self._get_feature_names()
        self.feature_version = FEATURE_VERSION
    
    def _get_feature_names(self) -> list:
        """Return list of feature names in order."""
        return FEATURE_LIST_V1
    
    def calculate_ichimoku(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculate Ichimoku indicator components.
        
        Args:
            df: DataFrame with OHLC data
            
        Returns:
            DataFrame with Ichimoku columns added
        """
        # Tenkan-sen (Conversion Line): (9-period high + 9-period low)/2
        period_high = df['high'].rolling(window=self.tenkan_period).max()
        period_low = df['low'].rolling(window=self.tenkan_period).min()
        df['tenkan_sen'] = (period_high + period_low) / 2
        
        # Kijun-sen (Base Line): (26-period high + 26-period low)/2
        period_high = df['high'].rolling(window=self.kijun_period).max()
        period_low = df['low'].rolling(window=self.kijun_period).min()
        df['kijun_sen'] = (period_high + period_low) / 2
        
        # Senkou Span A (Leading Span A): (Tenkan-sen + Kijun-sen)/2
        df['senkou_span_a'] = ((df['tenkan_sen'] + df['kijun_sen']) / 2).shift(self.kijun_period)
        
        # Senkou Span B (Leading Span B): (52-period high + 52-period low)/2
        period_high = df['high'].rolling(window=self.senkou_span_b_period).max()
        period_low = df['low'].rolling(window=self.senkou_span_b_period).min()
        df['senkou_span_b'] = ((period_high + period_low) / 2).shift(self.kijun_period)
        
        # Chikou Span (Lagging Span): Close shifted back 26 periods
        df['chikou_span'] = df['close'].shift(-self.kijun_period)
        
        return df
    
    def calculate_atr(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        """Calculate Average True Range."""
        high_low = df['high'] - df['low']
        high_close = np.abs(df['high'] - df['close'].shift())
        low_close = np.abs(df['low'] - df['close'].shift())
        
        true_range = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        atr = true_range.rolling(window=period).mean()
        
        return atr
    
    def calculate_adx(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        """Calculate Average Directional Index."""
        # Calculate +DM and -DM
        high_diff = df['high'].diff()
        low_diff = -df['low'].diff()
        
        plus_dm = high_diff.where((high_diff > low_diff) & (high_diff > 0), 0)
        minus_dm = low_diff.where((low_diff > high_diff) & (low_diff > 0), 0)
        
        # Calculate ATR
        atr = self.calculate_atr(df, period)
        
        # Calculate +DI and -DI
        plus_di = 100 * (plus_dm.rolling(window=period).mean() / atr)
        minus_di = 100 * (minus_dm.rolling(window=period).mean() / atr)
        
        # Calculate DX and ADX
        dx = 100 * np.abs(plus_di - minus_di) / (plus_di + minus_di)
        adx = dx.rolling(window=period).mean()
        
        return adx
    
    def calculate_slope(self, series: pd.Series, lookback: int = 3) -> pd.Series:
        """
        Calculate slope of a series (mirrors MQL5 implementation).
        
        Args:
            series: Price series
            lookback: Number of periods to look back
            
        Returns:
            Slope series
        """
        slope = (series - series.shift(lookback - 1)) / lookback
        # Normalize by current price and scale
        normalized_slope = (slope / series) * 100000.0
        return normalized_slope
    
    def build_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Build complete feature set mirroring MQL5 implementation.
        
        Args:
            df: DataFrame with columns: timestamp, open, high, low, close, tick_volume, spread
            
        Returns:
            DataFrame with all features added
        """
        # Make a copy to avoid modifying original
        df = df.copy()
        
        # Ensure proper datetime index
        if 'timestamp' in df.columns:
            df['timestamp'] = pd.to_datetime(df['timestamp'])
            df = df.set_index('timestamp')
        
        # Calculate Ichimoku
        df = self.calculate_ichimoku(df)
        
        # Calculate ATR
        df['atr'] = self.calculate_atr(df, self.atr_period)
        
        # Calculate ADX
        df['adx'] = self.calculate_adx(df, self.adx_period)
        
        # Feature 1: Tenkan slope
        df['tenkan_slope'] = self.calculate_slope(df['tenkan_sen'], lookback=3)
        
        # Feature 2: Kijun slope
        df['kijun_slope'] = self.calculate_slope(df['kijun_sen'], lookback=3)
        
        # Feature 3: Cloud thickness (normalized by ATR)
        df['cloud_thickness'] = (df['senkou_span_a'] - df['senkou_span_b']) / (df['atr'] + 0.00001)
        
        # Feature 4: Price vs Kumo distance (normalized by ATR)
        df['kumo_top'] = df[['senkou_span_a', 'senkou_span_b']].max(axis=1)
        df['kumo_bottom'] = df[['senkou_span_a', 'senkou_span_b']].min(axis=1)
        
        def calc_price_kumo_distance(row):
            if row['close'] > row['kumo_top']:
                return (row['close'] - row['kumo_top']) / (row['atr'] + 0.00001)
            elif row['close'] < row['kumo_bottom']:
                return (row['close'] - row['kumo_bottom']) / (row['atr'] + 0.00001)
            else:
                return 0.0
        
        df['price_kumo_distance'] = df.apply(calc_price_kumo_distance, axis=1)
        
        # Feature 5: Chikou relative position
        df['price_26_ago'] = df['close'].shift(self.kijun_period)
        df['chikou_relative_position'] = ((df['chikou_span'] - df['price_26_ago']) / 
                                          df['price_26_ago']) * 1000.0
        
        # Feature 6: ATR normalized
        df['atr_normalized'] = (df['atr'] / df['close']) * 10000.0
        
        # Feature 7: ADX (already calculated)
        # df['adx'] is already available
        
        # Feature 8: Tick volume spike ratio
        df['avg_volume'] = df['tick_volume'].rolling(window=20).mean()
        df['tick_volume_spike'] = df['tick_volume'] / (df['avg_volume'] + 0.00001)
        
        # Feature 9: Broker hour
        df['broker_hour'] = df.index.hour
        
        # Feature 10: Session ID
        def get_session_id(hour):
            if 0 <= hour < 8:
                return 0  # Asia
            elif 8 <= hour < 16:
                return 1  # London
            elif 16 <= hour < 24:
                return 2  # New York
            else:
                return 3  # Off-hours
        
        df['session_id'] = df['broker_hour'].apply(get_session_id)
        
        # Feature 11: Spread (assumed to be in the data already, or calculate from bid/ask)
        if 'spread' not in df.columns:
            df['spread'] = 0.0  # Placeholder - should be provided in data
        
        # Feature 12: Candle compression
        df['candle_range'] = df['high'] - df['low']
        df['avg_range'] = df['candle_range'].rolling(window=20).mean()
        df['candle_compression'] = df['candle_range'] / (df['avg_range'] + 0.00001)
        
        # Feature 13: Momentum strength (Tenkan slope * ADX)
        df['momentum_strength'] = df['tenkan_slope'] * df['adx']
        
        # Feature 14: Relative kumo strength (cloud thickness / ATR)
        df['relative_kumo_strength'] = df['cloud_thickness'] / (df['atr_normalized'] + 0.0001)
        
        # Feature 15: Market regime detection (v11)
        df = self.detect_market_regime(df)
        
        return df
    
    def detect_market_regime(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Classify market state: TREND, RANGE, CHOPPY (v11)
        Uses ADX and volatility measures
        
        Args:
            df: DataFrame with ADX and ATR features
            
        Returns:
            DataFrame with regime_flag added
        """
        df['regime_flag'] = 0  # 0=range (default)
        
        # Trend: ADX > 25
        df.loc[df['adx'] > 25, 'regime_flag'] = 1
        
        # Choppy: ATR spike + low ADX
        df.loc[(df['atr_normalized'] > 1.5) & (df['adx'] < 20), 'regime_flag'] = 2
        
        return df
    
    def add_feature_metadata(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Add feature version and timestamp for tracking (v11)
        
        Args:
            df: DataFrame with features
            
        Returns:
            DataFrame with metadata columns added
        """
        from datetime import datetime
        df['feature_version'] = self.feature_version
        df['feature_timestamp'] = datetime.now().isoformat()
        return df
    
    def get_feature_vector(self, df: pd.DataFrame) -> np.ndarray:
        """
        Extract feature vector in the correct order for ML model.
        
        Args:
            df: DataFrame with calculated features
            
        Returns:
            NumPy array with features in correct order
        """
        # Ensure all features are calculated
        if 'tenkan_slope' not in df.columns:
            df = self.build_features(df)
        
        # Extract features in the exact order expected by the model
        feature_vector = df[self.feature_names].values
        
        # Replace NaN with 0
        feature_vector = np.nan_to_num(feature_vector, nan=0.0, posinf=0.0, neginf=0.0)
        
        return feature_vector
    
    def prepare_dataset(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, np.ndarray]:
        """
        Prepare complete dataset with features.
        
        Args:
            df: Raw OHLC DataFrame
            
        Returns:
            Tuple of (DataFrame with features, feature array)
        """
        # Build all features
        df_features = self.build_features(df)
        
        # Get feature array
        X = self.get_feature_vector(df_features)
        
        return df_features, X


def main():
    """
    Example usage and testing.
    """
    print("=" * 60)
    print("TrendAI v10 Feature Engineering Module")
    print("=" * 60)
    
    # Create sample data for testing
    dates = pd.date_range('2024-01-01', periods=1000, freq='15T')
    np.random.seed(42)
    
    df = pd.DataFrame({
        'timestamp': dates,
        'open': 150.0 + np.cumsum(np.random.randn(1000) * 0.01),
        'high': 150.0 + np.cumsum(np.random.randn(1000) * 0.01) + 0.05,
        'low': 150.0 + np.cumsum(np.random.randn(1000) * 0.01) - 0.05,
        'close': 150.0 + np.cumsum(np.random.randn(1000) * 0.01),
        'tick_volume': np.random.randint(100, 1000, 1000),
        'spread': np.random.uniform(0.5, 3.0, 1000)
    })
    
    # Initialize feature engineer
    fe = FeatureEngineer()
    
    # Build features
    print("\nBuilding features...")
    df_features, X = fe.prepare_dataset(df)
    
    print(f"✓ Features calculated successfully")
    print(f"  Dataset shape: {X.shape}")
    print(f"  Number of features: {len(fe.feature_names)}")
    print(f"\nFeature names:")
    for i, name in enumerate(fe.feature_names):
        print(f"  {i+1:2d}. {name}")
    
    print(f"\nFeature statistics (last row):")
    for i, name in enumerate(fe.feature_names):
        print(f"  {name:30s}: {X[-1, i]:10.4f}")
    
    print("\n" + "=" * 60)
    print("Feature engineering module ready for production use")
    print("=" * 60)


if __name__ == "__main__":
    main()
