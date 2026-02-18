"""
Data Collection Module for TrendAI v11
======================================

Collects historical USDJPY M15 data from multiple sources:
1. MetaTrader5 Python API (primary method)
2. yfinance (fallback for users without MT5 Python access)
3. Realistic synthetic data (final fallback)

Author: TrendAI Development Team
Version: 11.0
"""

import pandas as pd
import numpy as np
import os
from datetime import datetime, timedelta
from typing import Optional
import warnings
warnings.filterwarnings('ignore')


def collect_from_mt5(symbol: str = "USDJPY", timeframe_mt5=None, days: int = 730) -> pd.DataFrame:
    """
    Collect historical data from MetaTrader5 terminal.
    
    Args:
        symbol: Trading symbol (default: "USDJPY")
        timeframe_mt5: MT5 timeframe constant (default: TIMEFRAME_M15)
        days: Number of days of history to collect (default: 730 = 2 years)
        
    Returns:
        DataFrame with columns: timestamp, open, high, low, close, tick_volume, spread
        
    Raises:
        Exception: If MT5 connection or data retrieval fails
    """
    try:
        import MetaTrader5 as mt5
        
        # Use default timeframe if not provided
        if timeframe_mt5 is None:
            timeframe_mt5 = mt5.TIMEFRAME_M15
        
        print("Attempting to connect to MetaTrader5...")
        
        # Initialize MT5 connection
        if not mt5.initialize():
            raise Exception(f"MT5 initialization failed: {mt5.last_error()}")
        
        print(f"✓ Connected to MT5")
        print(f"  Terminal: {mt5.terminal_info()}")
        print(f"  Account: {mt5.account_info().login if mt5.account_info() else 'Not logged in'}")
        
        # Calculate date range
        utc_to = datetime.now()
        utc_from = utc_to - timedelta(days=days)
        
        print(f"\nDownloading {symbol} M15 data...")
        print(f"  From: {utc_from.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  To:   {utc_to.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Get rates
        rates = mt5.copy_rates_range(symbol, timeframe_mt5, utc_from, utc_to)
        
        # Shutdown MT5 connection
        mt5.shutdown()
        
        if rates is None or len(rates) == 0:
            raise Exception(f"No data received from MT5 for {symbol}")
        
        # Convert to DataFrame
        df = pd.DataFrame(rates)
        df['timestamp'] = pd.to_datetime(df['time'], unit='s')
        
        # Select and rename columns
        df = df[['timestamp', 'open', 'high', 'low', 'close', 'tick_volume', 'spread']].copy()
        
        print(f"✓ Downloaded {len(df)} candles from MT5")
        print(f"  Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
        print(f"  Price range: {df['close'].min():.3f} - {df['close'].max():.3f}")
        
        return df
        
    except ImportError:
        raise Exception("MetaTrader5 package not installed. Install with: pip install MetaTrader5")
    except Exception as e:
        raise Exception(f"MT5 data collection failed: {str(e)}")


def collect_from_yfinance(symbol: str = "USDJPY=X", interval: str = "15m", period: str = "60d") -> pd.DataFrame:
    """
    Collect historical data from Yahoo Finance.
    
    Note: yfinance has limitations on 15-minute data (typically max 60 days).
    For longer history, multiple calls or different intervals may be needed.
    
    Args:
        symbol: Yahoo Finance ticker (default: "USDJPY=X")
        interval: Data interval (default: "15m")
        period: Time period to fetch (default: "60d")
        
    Returns:
        DataFrame with columns: timestamp, open, high, low, close, tick_volume, spread
        
    Raises:
        Exception: If yfinance data retrieval fails
    """
    try:
        import yfinance as yf
        
        print(f"Attempting to download {symbol} data from Yahoo Finance...")
        print(f"  Interval: {interval}")
        print(f"  Period: {period}")
        
        # Download data
        ticker = yf.Ticker(symbol)
        df = ticker.history(period=period, interval=interval)
        
        if df is None or len(df) == 0:
            raise Exception(f"No data received from yfinance for {symbol}")
        
        # Reset index to get timestamp as column
        df = df.reset_index()
        
        # Rename columns to match our format
        df = df.rename(columns={
            'Datetime': 'timestamp',
            'Open': 'open',
            'High': 'high',
            'Low': 'low',
            'Close': 'close',
            'Volume': 'tick_volume'
        })
        
        # Add spread column (estimate as 0.02 for USDJPY, which is ~2 pips)
        df['spread'] = 0.02
        
        # Select only needed columns
        df = df[['timestamp', 'open', 'high', 'low', 'close', 'tick_volume', 'spread']].copy()
        
        # Ensure timestamp is datetime
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        
        print(f"✓ Downloaded {len(df)} candles from yfinance")
        print(f"  Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
        print(f"  Price range: {df['close'].min():.3f} - {df['close'].max():.3f}")
        
        return df
        
    except ImportError:
        raise Exception("yfinance package not installed. Install with: pip install yfinance")
    except Exception as e:
        raise Exception(f"yfinance data collection failed: {str(e)}")


def generate_realistic_usdjpy(num_candles: int = 50000) -> pd.DataFrame:
    """
    Generate realistic USDJPY M15 synthetic data.
    
    This is a fallback method that generates data with:
    - Realistic USDJPY price levels (148-156 range)
    - Trending and ranging regimes
    - Realistic M15 candle ranges (5-30 pips)
    - Session-based volatility (higher during London/NY sessions)
    - Movements large enough for label generator to find continuation signals
    
    Args:
        num_candles: Number of 15-minute candles to generate (default: 50000 ≈ 520 days)
        
    Returns:
        DataFrame with columns: timestamp, open, high, low, close, tick_volume, spread
    """
    print(f"Generating {num_candles} candles of realistic USDJPY M15 synthetic data...")
    
    np.random.seed(42)
    
    # Generate timestamps (15-minute intervals)
    start_date = datetime(2023, 1, 1)
    dates = pd.date_range(start_date, periods=num_candles, freq='15T')
    
    # Initialize price array
    base_price = 152.0  # Realistic USDJPY level
    prices = np.zeros(num_candles)
    prices[0] = base_price
    
    # Generate price movements with trending and ranging regimes
    # Use regime switching to create realistic market behavior
    regime_length = 500  # candles per regime (≈5 days)
    num_regimes = num_candles // regime_length + 1
    
    # Define regimes: 0=ranging, 1=uptrend, 2=downtrend
    regimes = np.random.choice([0, 1, 2], size=num_regimes, p=[0.4, 0.3, 0.3])
    
    idx = 0
    for regime_idx, regime in enumerate(regimes):
        regime_start = regime_idx * regime_length
        regime_end = min((regime_idx + 1) * regime_length, num_candles)
        
        if regime == 0:  # Ranging
            # Small random movements
            for i in range(regime_start, regime_end):
                if i > 0:
                    # Small mean-reverting movements
                    center = prices[max(0, i-100):i].mean() if i > 100 else base_price
                    drift = (center - prices[i-1]) * 0.02
                    volatility = np.random.randn() * 0.03  # ±3 pips per candle
                    prices[i] = prices[i-1] + drift + volatility
                    
        elif regime == 1:  # Uptrend
            # Consistent upward movements
            for i in range(regime_start, regime_end):
                if i > 0:
                    trend = 0.04  # +4 pips per candle on average
                    volatility = np.random.randn() * 0.05  # ±5 pips per candle
                    prices[i] = prices[i-1] + trend + volatility
                    
        else:  # Downtrend
            # Consistent downward movements
            for i in range(regime_start, regime_end):
                if i > 0:
                    trend = -0.04  # -4 pips per candle on average
                    volatility = np.random.randn() * 0.05  # ±5 pips per candle
                    prices[i] = prices[i-1] + trend + volatility
    
    # Keep prices in realistic range (147-157)
    prices = np.clip(prices, 147.0, 157.0)
    
    # Generate OHLC from close prices
    df_data = []
    
    for i, (timestamp, close_price) in enumerate(zip(dates, prices)):
        # Determine session (for volatility adjustment)
        hour = timestamp.hour
        
        # London (8-16) and NY (13-21) sessions have higher volatility
        is_high_volatility_session = (8 <= hour < 16) or (13 <= hour < 21)
        
        if is_high_volatility_session:
            # Higher range during active sessions (10-30 pips)
            range_pips = np.random.uniform(0.10, 0.30)
        else:
            # Lower range during quiet sessions (5-15 pips)
            range_pips = np.random.uniform(0.05, 0.15)
        
        # Generate high/low around close
        high_offset = np.random.uniform(0.3, 0.7) * range_pips
        low_offset = np.random.uniform(0.3, 0.7) * range_pips
        
        high = close_price + high_offset
        low = close_price - low_offset
        
        # Open is somewhere between high and low
        open_price = np.random.uniform(low + 0.01, high - 0.01)
        
        # Ensure OHLC integrity
        high = max(high, open_price, close_price)
        low = min(low, open_price, close_price)
        
        # Volume varies by session
        if is_high_volatility_session:
            volume = np.random.randint(300, 1500)
        else:
            volume = np.random.randint(50, 400)
        
        # Spread (1-3 pips)
        spread = np.random.uniform(0.01, 0.03)
        
        df_data.append({
            'timestamp': timestamp,
            'open': open_price,
            'high': high,
            'low': low,
            'close': close_price,
            'tick_volume': volume,
            'spread': spread
        })
    
    df = pd.DataFrame(df_data)
    
    print(f"✓ Generated {len(df)} candles of synthetic data")
    print(f"  Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
    print(f"  Price range: {df['close'].min():.3f} - {df['close'].max():.3f}")
    print(f"  Mean candle range: {(df['high'] - df['low']).mean():.3f} ({(df['high'] - df['low']).mean() / 0.01:.1f} pips)")
    
    return df


def load_data(data_path: str = "data/usdjpy_m15.csv") -> pd.DataFrame:
    """
    Load historical data from CSV file.
    
    Args:
        data_path: Path to CSV file (default: "data/usdjpy_m15.csv")
        
    Returns:
        DataFrame with columns: timestamp, open, high, low, close, tick_volume, spread
        
    Raises:
        FileNotFoundError: If CSV file doesn't exist
    """
    if not os.path.exists(data_path):
        raise FileNotFoundError(f"Data file not found: {data_path}")
    
    print(f"Loading data from {data_path}...")
    
    df = pd.read_csv(data_path)
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    
    # Validate columns
    required_columns = ['timestamp', 'open', 'high', 'low', 'close', 'tick_volume', 'spread']
    missing_columns = set(required_columns) - set(df.columns)
    if missing_columns:
        raise ValueError(f"CSV is missing required columns: {missing_columns}")
    
    print(f"✓ Loaded {len(df)} candles")
    print(f"  Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
    
    return df


def main():
    """
    Main data collection workflow.
    
    Tries methods in order:
    1. MetaTrader5 (best - real data, 2+ years)
    2. yfinance (good - real data, limited history)
    3. Realistic synthetic (fallback - for testing)
    """
    print("=" * 60)
    print("TrendAI v11 Data Collection Module")
    print("=" * 60)
    print()
    
    # Ensure data directory exists
    data_dir = os.path.join(os.path.dirname(__file__), 'data')
    os.makedirs(data_dir, exist_ok=True)
    print(f"✓ Data directory ready: {data_dir}\n")
    
    df = None
    method_used = None
    
    # Try Method 1: MetaTrader5
    print("Method 1: Attempting MT5 data collection...")
    try:
        df = collect_from_mt5(symbol="USDJPY", days=730)
        method_used = "MetaTrader5"
        print(f"\n✓ Successfully collected data via {method_used}\n")
    except Exception as e:
        print(f"✗ MT5 collection failed: {str(e)}\n")
    
    # Try Method 2: yfinance
    if df is None:
        print("Method 2: Attempting yfinance data collection...")
        try:
            df = collect_from_yfinance(symbol="USDJPY=X", interval="15m", period="60d")
            method_used = "yfinance"
            print(f"\n✓ Successfully collected data via {method_used}\n")
        except Exception as e:
            print(f"✗ yfinance collection failed: {str(e)}\n")
    
    # Try Method 3: Realistic synthetic
    if df is None:
        print("Method 3: Using realistic synthetic data generation...")
        df = generate_realistic_usdjpy(num_candles=50000)
        method_used = "realistic_synthetic"
        print(f"\n✓ Successfully generated data via {method_used}\n")
    
    # Save to CSV
    output_path = os.path.join(data_dir, 'usdjpy_m15.csv')
    df.to_csv(output_path, index=False)
    print(f"✓ Data saved to: {output_path}")
    print(f"  Method used: {method_used}")
    print(f"  Total candles: {len(df)}")
    print(f"  Memory usage: {df.memory_usage(deep=True).sum() / 1024 / 1024:.2f} MB")
    
    print("\n" + "=" * 60)
    print("Data collection complete!")
    print("You can now run: python train_model.py")
    print("=" * 60)
    
    return df


if __name__ == "__main__":
    main()
