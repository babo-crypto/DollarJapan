"""
Broker Time Analysis Module for TrendAI v10
============================================

Analyzes trading performance by broker hour and session:
- Performance heatmaps by hour
- Session profitability analysis
- Optimal trading windows identification
- Volatility patterns by time

Author: TrendAI Development Team
Version: 10.0
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List
import warnings
warnings.filterwarnings('ignore')


class BrokerTimeAnalyzer:
    """
    Analyze trading performance patterns by time of day.
    """
    
    def __init__(self):
        """Initialize broker time analyzer."""
        self.hourly_stats = None
        self.session_stats = None
    
    def get_session_from_hour(self, hour: int) -> str:
        """
        Map broker hour to trading session.
        
        Args:
            hour: Broker hour (0-23)
            
        Returns:
            Session name
        """
        if 0 <= hour < 8:
            return 'ASIA'
        elif 8 <= hour < 16:
            return 'LONDON'
        elif 16 <= hour < 24:
            return 'NEWYORK'
        else:
            return 'OFF_HOURS'
    
    def analyze_hourly_performance(self, df: pd.DataFrame, 
                                   predictions: np.ndarray,
                                   labels: np.ndarray) -> pd.DataFrame:
        """
        Analyze model performance by broker hour.
        
        Args:
            df: DataFrame with timestamp index
            predictions: Model predictions
            labels: True labels
            
        Returns:
            DataFrame with hourly statistics
        """
        # Extract hour
        hours = df.index.hour
        
        # Calculate accuracy by hour
        hourly_data = []
        
        for hour in range(24):
            hour_mask = (hours == hour)
            
            if hour_mask.sum() == 0:
                continue
            
            hour_preds = predictions[hour_mask]
            hour_labels = labels[hour_mask]
            
            # Calculate metrics
            accuracy = (hour_preds == hour_labels).mean()
            total_samples = hour_mask.sum()
            positive_rate = (hour_labels == 1).mean()
            
            # Get session
            session = self.get_session_from_hour(hour)
            
            hourly_data.append({
                'hour': hour,
                'session': session,
                'accuracy': accuracy,
                'total_samples': total_samples,
                'positive_rate': positive_rate
            })
        
        self.hourly_stats = pd.DataFrame(hourly_data)
        return self.hourly_stats
    
    def analyze_session_performance(self, hourly_stats: pd.DataFrame) -> pd.DataFrame:
        """
        Aggregate performance by trading session.
        
        Args:
            hourly_stats: DataFrame with hourly statistics
            
        Returns:
            DataFrame with session statistics
        """
        session_stats = hourly_stats.groupby('session').agg({
            'accuracy': 'mean',
            'total_samples': 'sum',
            'positive_rate': 'mean'
        }).reset_index()
        
        self.session_stats = session_stats
        return session_stats
    
    def analyze_volatility_by_hour(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Analyze price volatility by broker hour.
        
        Args:
            df: DataFrame with OHLC data
            
        Returns:
            DataFrame with hourly volatility statistics
        """
        # Calculate returns
        df['returns'] = df['close'].pct_change()
        df['range'] = df['high'] - df['low']
        
        # Extract hour
        df['hour'] = df.index.hour
        
        # Calculate hourly volatility
        hourly_vol = df.groupby('hour').agg({
            'returns': lambda x: x.std() * np.sqrt(252 * 96),  # Annualized for 15min bars
            'range': 'mean',
            'tick_volume': 'mean' if 'tick_volume' in df.columns else lambda x: 0
        }).reset_index()
        
        hourly_vol.columns = ['hour', 'volatility', 'avg_range', 'avg_volume']
        hourly_vol['session'] = hourly_vol['hour'].apply(self.get_session_from_hour)
        
        return hourly_vol
    
    def identify_optimal_hours(self, hourly_stats: pd.DataFrame,
                              min_accuracy: float = 0.55,
                              min_samples: int = 100) -> List[int]:
        """
        Identify optimal trading hours based on performance.
        
        Args:
            hourly_stats: DataFrame with hourly statistics
            min_accuracy: Minimum accuracy threshold
            min_samples: Minimum sample count
            
        Returns:
            List of optimal hours
        """
        optimal = hourly_stats[
            (hourly_stats['accuracy'] >= min_accuracy) &
            (hourly_stats['total_samples'] >= min_samples)
        ]
        
        return optimal['hour'].tolist()
    
    def plot_hourly_heatmap(self, hourly_stats: pd.DataFrame, 
                           save_path: str = None):
        """
        Create heatmap of performance by hour.
        
        Args:
            hourly_stats: DataFrame with hourly statistics
            save_path: Optional path to save figure
        """
        # Prepare data for heatmap
        pivot_data = hourly_stats.pivot_table(
            index='session',
            columns='hour',
            values='accuracy',
            aggfunc='mean'
        )
        
        # Create figure
        plt.figure(figsize=(16, 4))
        sns.heatmap(pivot_data, annot=True, fmt='.3f', cmap='RdYlGn',
                   center=0.5, vmin=0, vmax=1, cbar_kws={'label': 'Accuracy'})
        plt.title('Model Accuracy by Broker Hour and Session', fontsize=14, fontweight='bold')
        plt.xlabel('Broker Hour')
        plt.ylabel('Trading Session')
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"✓ Heatmap saved to {save_path}")
        else:
            plt.show()
        
        plt.close()
    
    def plot_session_comparison(self, session_stats: pd.DataFrame,
                               save_path: str = None):
        """
        Create bar chart comparing session performance.
        
        Args:
            session_stats: DataFrame with session statistics
            save_path: Optional path to save figure
        """
        fig, axes = plt.subplots(1, 3, figsize=(15, 5))
        
        # Plot 1: Accuracy by session
        axes[0].bar(session_stats['session'], session_stats['accuracy'], 
                   color=['#3498db', '#e74c3c', '#2ecc71', '#95a5a6'])
        axes[0].set_title('Accuracy by Session', fontweight='bold')
        axes[0].set_ylabel('Accuracy')
        axes[0].set_ylim([0, 1])
        axes[0].axhline(y=0.5, color='red', linestyle='--', alpha=0.5, label='Random')
        axes[0].legend()
        axes[0].grid(axis='y', alpha=0.3)
        
        # Plot 2: Sample count by session
        axes[1].bar(session_stats['session'], session_stats['total_samples'],
                   color=['#3498db', '#e74c3c', '#2ecc71', '#95a5a6'])
        axes[1].set_title('Sample Count by Session', fontweight='bold')
        axes[1].set_ylabel('Samples')
        axes[1].grid(axis='y', alpha=0.3)
        
        # Plot 3: Positive rate by session
        axes[2].bar(session_stats['session'], session_stats['positive_rate'],
                   color=['#3498db', '#e74c3c', '#2ecc71', '#95a5a6'])
        axes[2].set_title('Positive Label Rate by Session', fontweight='bold')
        axes[2].set_ylabel('Positive Rate')
        axes[2].set_ylim([0, 1])
        axes[2].axhline(y=0.5, color='red', linestyle='--', alpha=0.5, label='Balanced')
        axes[2].legend()
        axes[2].grid(axis='y', alpha=0.3)
        
        plt.suptitle('Trading Session Performance Analysis', 
                    fontsize=16, fontweight='bold', y=1.02)
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"✓ Session comparison saved to {save_path}")
        else:
            plt.show()
        
        plt.close()
    
    def generate_session_config(self, session_stats: pd.DataFrame,
                               optimal_hours: List[int],
                               output_path: str = '../models/session_config.json') -> Dict:
        """
        Generate session configuration file for EA.
        
        Args:
            session_stats: DataFrame with session statistics
            optimal_hours: List of optimal trading hours
            output_path: Output file path
            
        Returns:
            Configuration dictionary
        """
        import json
        
        config = {
            'optimal_hours': optimal_hours,
            'session_performance': {},
            'recommended_sessions': []
        }
        
        # Add session performance
        for _, row in session_stats.iterrows():
            session_name = row['session']
            config['session_performance'][session_name] = {
                'accuracy': float(row['accuracy']),
                'total_samples': int(row['total_samples']),
                'positive_rate': float(row['positive_rate']),
                'recommended': row['accuracy'] > 0.55
            }
            
            if row['accuracy'] > 0.55:
                config['recommended_sessions'].append(session_name)
        
        # Save to file
        with open(output_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✓ Session config saved to {output_path}")
        
        return config


def main():
    """
    Example analysis workflow.
    """
    print("=" * 60)
    print("TrendAI v10 Broker Time Analysis Module")
    print("=" * 60)
    
    # Create synthetic data
    dates = pd.date_range('2024-01-01', periods=10000, freq='15T')
    np.random.seed(42)
    
    base_price = 150.0
    price_changes = np.cumsum(np.random.randn(10000) * 0.01)
    
    df = pd.DataFrame({
        'open': base_price + price_changes,
        'high': base_price + price_changes + np.abs(np.random.randn(10000) * 0.02),
        'low': base_price + price_changes - np.abs(np.random.randn(10000) * 0.02),
        'close': base_price + price_changes,
        'tick_volume': np.random.randint(100, 1000, 10000)
    }, index=dates)
    
    # Generate synthetic predictions and labels
    predictions = np.random.randint(0, 2, 10000)
    labels = np.random.randint(0, 2, 10000)
    
    # Initialize analyzer
    analyzer = BrokerTimeAnalyzer()
    
    # Analyze hourly performance
    print("\nAnalyzing hourly performance...")
    hourly_stats = analyzer.analyze_hourly_performance(df, predictions, labels)
    print("✓ Hourly analysis complete")
    print(f"\nHourly Statistics Sample:")
    print(hourly_stats.head(10))
    
    # Analyze session performance
    print("\nAnalyzing session performance...")
    session_stats = analyzer.analyze_session_performance(hourly_stats)
    print("✓ Session analysis complete")
    print(f"\nSession Statistics:")
    print(session_stats)
    
    # Identify optimal hours
    print("\nIdentifying optimal trading hours...")
    optimal_hours = analyzer.identify_optimal_hours(hourly_stats, 
                                                    min_accuracy=0.5, 
                                                    min_samples=100)
    print(f"✓ Optimal hours identified: {optimal_hours}")
    
    # Generate session config
    print("\nGenerating session configuration...")
    config = analyzer.generate_session_config(session_stats, optimal_hours)
    print("✓ Session configuration generated")
    
    # Note about plots
    print("\nNote: Plotting functions available but skipped in this example.")
    print("Call plot_hourly_heatmap() and plot_session_comparison() to generate charts.")
    
    print("\n" + "=" * 60)
    print("Broker time analysis complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()
