"""
Model Training Module for TrendAI v10
======================================

Trains LightGBM/XGBoost models with:
- Walk-forward validation (v11)
- Hyperparameter tuning
- Feature importance analysis
- Broker hour analytics
- Model performance evaluation

Author: TrendAI Development Team
Version: 11.0
"""

import pandas as pd
import numpy as np
import lightgbm as lgb
import xgboost as xgb
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
from sklearn.preprocessing import StandardScaler
import json
import pickle
import os
from datetime import datetime, timedelta
from typing import Dict, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

from feature_engineering import FeatureEngineer
from label_generator import LabelGenerator


class ModelTrainer:
    """
    Train and evaluate ML models for continuation prediction.
    """
    
    def __init__(self, model_type: str = 'lightgbm'):
        """
        Initialize model trainer.
        
        Args:
            model_type: 'lightgbm' or 'xgboost'
        """
        self.model_type = model_type
        self.model = None
        self.scaler = StandardScaler()
        self.feature_engineer = FeatureEngineer()
        self.label_generator = LabelGenerator()
        self.feature_importance = None
        self.training_history = []
    
    def prepare_data(self, df: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray, pd.DataFrame]:
        """
        Prepare features and labels from raw data.
        
        Args:
            df: Raw OHLC DataFrame
            
        Returns:
            Tuple of (features, labels, feature_df)
        """
        print("Preparing data...")
        
        # Build features
        df_features, X = self.feature_engineer.prepare_dataset(df)
        
        # Generate labels
        price_kumo_distance = df_features['price_kumo_distance']
        atr = df_features['atr']
        
        label_data = self.label_generator.generate_labels_with_metadata(
            df_features, price_kumo_distance, atr
        )
        
        # Filter valid samples
        valid_mask = label_data['is_valid']
        X = X[valid_mask]
        y = label_data['label'][valid_mask].values
        df_features = df_features[valid_mask]
        
        print(f"✓ Data prepared: {X.shape[0]} samples, {X.shape[1]} features")
        
        # Print label distribution
        unique, counts = np.unique(y, return_counts=True)
        print(f"  Label distribution:")
        for label, count in zip(unique, counts):
            print(f"    Class {label}: {count} ({count/len(y)*100:.1f}%)")
        
        return X, y, df_features
    
    def split_data_walk_forward(self, X: np.ndarray, y: np.ndarray,
                                n_splits: int = 5) -> TimeSeriesSplit:
        """
        Create walk-forward validation splits.
        
        Args:
            X: Feature array
            y: Label array
            n_splits: Number of splits
            
        Returns:
            TimeSeriesSplit object
        """
        tscv = TimeSeriesSplit(n_splits=n_splits)
        return tscv
    
    def train_lightgbm(self, X_train: np.ndarray, y_train: np.ndarray,
                      X_val: np.ndarray, y_val: np.ndarray,
                      params: Optional[Dict] = None) -> lgb.Booster:
        """
        Train LightGBM model.
        
        Args:
            X_train: Training features
            y_train: Training labels
            X_val: Validation features
            y_val: Validation labels
            params: Model parameters
            
        Returns:
            Trained LightGBM model
        """
        if params is None:
            params = {
                'objective': 'binary',
                'metric': 'binary_logloss',
                'boosting_type': 'gbdt',
                'num_leaves': 31,
                'learning_rate': 0.05,
                'feature_fraction': 0.8,
                'bagging_fraction': 0.8,
                'bagging_freq': 5,
                'max_depth': 7,
                'min_data_in_leaf': 20,
                'lambda_l1': 0.1,
                'lambda_l2': 0.1,
                'verbose': -1
            }
        
        # Create datasets
        train_data = lgb.Dataset(X_train, label=y_train)
        val_data = lgb.Dataset(X_val, label=y_val, reference=train_data)
        
        # Train model
        model = lgb.train(
            params,
            train_data,
            num_boost_round=500,
            valid_sets=[train_data, val_data],
            valid_names=['train', 'val'],
            callbacks=[lgb.early_stopping(stopping_rounds=50), lgb.log_evaluation(50)]
        )
        
        return model
    
    def train_xgboost(self, X_train: np.ndarray, y_train: np.ndarray,
                     X_val: np.ndarray, y_val: np.ndarray,
                     params: Optional[Dict] = None) -> xgb.Booster:
        """
        Train XGBoost model.
        
        Args:
            X_train: Training features
            y_train: Training labels
            X_val: Validation features
            y_val: Validation labels
            params: Model parameters
            
        Returns:
            Trained XGBoost model
        """
        if params is None:
            params = {
                'objective': 'binary:logistic',
                'eval_metric': 'logloss',
                'max_depth': 7,
                'learning_rate': 0.05,
                'subsample': 0.8,
                'colsample_bytree': 0.8,
                'min_child_weight': 3,
                'gamma': 0.1,
                'reg_alpha': 0.1,
                'reg_lambda': 1.0,
                'tree_method': 'hist'
            }
        
        # Create DMatrix
        dtrain = xgb.DMatrix(X_train, label=y_train)
        dval = xgb.DMatrix(X_val, label=y_val)
        
        # Train model
        evals = [(dtrain, 'train'), (dval, 'val')]
        model = xgb.train(
            params,
            dtrain,
            num_boost_round=500,
            evals=evals,
            early_stopping_rounds=50,
            verbose_eval=50
        )
        
        return model
    
    def evaluate_model(self, model, X: np.ndarray, y: np.ndarray) -> Dict:
        """
        Evaluate model performance.
        
        Args:
            model: Trained model
            X: Features
            y: Labels
            
        Returns:
            Dictionary with evaluation metrics
        """
        # Get predictions
        if self.model_type == 'lightgbm':
            y_pred_proba = model.predict(X)
        else:  # xgboost
            dmatrix = xgb.DMatrix(X)
            y_pred_proba = model.predict(dmatrix)
        
        y_pred = (y_pred_proba >= 0.5).astype(int)
        
        # Calculate metrics
        metrics = {
            'accuracy': accuracy_score(y, y_pred),
            'precision': precision_score(y, y_pred, zero_division=0),
            'recall': recall_score(y, y_pred, zero_division=0),
            'f1_score': f1_score(y, y_pred, zero_division=0),
            'roc_auc': roc_auc_score(y, y_pred_proba) if len(np.unique(y)) > 1 else 0.0
        }
        
        return metrics
    
    def train_with_walk_forward(self, X: np.ndarray, y: np.ndarray,
                                n_splits: int = 5) -> Dict:
        """
        Train model using walk-forward validation.
        
        Args:
            X: Feature array
            y: Label array
            n_splits: Number of splits
            
        Returns:
            Dictionary with training results
        """
        print(f"\n{'='*60}")
        print(f"Walk-Forward Validation Training ({n_splits} splits)")
        print(f"{'='*60}\n")
        
        tscv = self.split_data_walk_forward(X, y, n_splits)
        
        fold_metrics = []
        
        for fold, (train_idx, val_idx) in enumerate(tscv.split(X), 1):
            print(f"\nFold {fold}/{n_splits}")
            print(f"  Train samples: {len(train_idx)}")
            print(f"  Val samples: {len(val_idx)}")
            
            X_train, X_val = X[train_idx], X[val_idx]
            y_train, y_val = y[train_idx], y[val_idx]
            
            # Normalize features
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_val_scaled = self.scaler.transform(X_val)
            
            # Train model
            if self.model_type == 'lightgbm':
                model = self.train_lightgbm(X_train_scaled, y_train, X_val_scaled, y_val)
            else:
                model = self.train_xgboost(X_train_scaled, y_train, X_val_scaled, y_val)
            
            # Evaluate
            train_metrics = self.evaluate_model(model, X_train_scaled, y_train)
            val_metrics = self.evaluate_model(model, X_val_scaled, y_val)
            
            print(f"\n  Train metrics: Acc={train_metrics['accuracy']:.4f}, " +
                  f"Prec={train_metrics['precision']:.4f}, " +
                  f"Rec={train_metrics['recall']:.4f}, " +
                  f"F1={train_metrics['f1_score']:.4f}, " +
                  f"AUC={train_metrics['roc_auc']:.4f}")
            
            print(f"  Val metrics:   Acc={val_metrics['accuracy']:.4f}, " +
                  f"Prec={val_metrics['precision']:.4f}, " +
                  f"Rec={val_metrics['recall']:.4f}, " +
                  f"F1={val_metrics['f1_score']:.4f}, " +
                  f"AUC={val_metrics['roc_auc']:.4f}")
            
            fold_metrics.append({
                'fold': fold,
                'train_metrics': train_metrics,
                'val_metrics': val_metrics
            })
        
        # Calculate average metrics
        avg_val_metrics = {
            metric: np.mean([fm['val_metrics'][metric] for fm in fold_metrics])
            for metric in fold_metrics[0]['val_metrics'].keys()
        }
        
        print(f"\n{'='*60}")
        print(f"Average Validation Metrics:")
        print(f"{'='*60}")
        for metric, value in avg_val_metrics.items():
            print(f"  {metric:15s}: {value:.4f}")
        
        # Train final model on all data
        print(f"\nTraining final model on all data...")
        X_scaled = self.scaler.fit_transform(X)
        
        if self.model_type == 'lightgbm':
            self.model = self.train_lightgbm(X_scaled, y, X_scaled, y)
        else:
            self.model = self.train_xgboost(X_scaled, y, X_scaled, y)
        
        print(f"✓ Final model trained")
        
        # Extract feature importance
        if self.model_type == 'lightgbm':
            self.feature_importance = pd.DataFrame({
                'feature': self.feature_engineer.feature_names,
                'importance': self.model.feature_importance(importance_type='gain')
            }).sort_values('importance', ascending=False)
        else:
            importance_dict = self.model.get_score(importance_type='gain')
            self.feature_importance = pd.DataFrame({
                'feature': [f'f{i}' for i in range(len(self.feature_engineer.feature_names))],
                'importance': [importance_dict.get(f'f{i}', 0) for i in range(len(self.feature_engineer.feature_names))]
            }).sort_values('importance', ascending=False)
        
        return {
            'fold_metrics': fold_metrics,
            'avg_val_metrics': avg_val_metrics,
            'feature_importance': self.feature_importance
        }
    
    def save_model(self, output_dir: str = '../models'):
        """
        Save trained model and scaler.
        
        Args:
            output_dir: Output directory path
        """
        import os
        os.makedirs(output_dir, exist_ok=True)
        
        # Save model
        if self.model_type == 'lightgbm':
            model_path = f'{output_dir}/trendai_v10_lgb.pkl'
            with open(model_path, 'wb') as f:
                pickle.dump(self.model, f)
        else:
            model_path = f'{output_dir}/trendai_v10_xgb.pkl'
            with open(model_path, 'wb') as f:
                pickle.dump(self.model, f)
        
        print(f"✓ Model saved to {model_path}")
        
        # Save scaler
        scaler_data = {
            'means': self.scaler.mean_.tolist(),
            'stds': self.scaler.scale_.tolist()
        }
        scaler_path = f'{output_dir}/scaler.json'
        with open(scaler_path, 'w') as f:
            json.dump(scaler_data, f, indent=2)
        
        print(f"✓ Scaler saved to {scaler_path}")
        
        # Save feature importance
        if self.feature_importance is not None:
            importance_path = f'{output_dir}/feature_importance.csv'
            self.feature_importance.to_csv(importance_path, index=False)
            print(f"✓ Feature importance saved to {importance_path}")


def walk_forward_validation(df: pd.DataFrame, n_splits: int = 5, 
                            train_months: int = 6, test_months: int = 1) -> pd.DataFrame:
    """
    Walk-forward expanding window validation (v11)
    Prevents overfitting by testing on unseen future data
    
    Args:
        df: DataFrame with features and labels (must have 'timestamp' column)
        n_splits: Number of validation folds
        train_months: Training window size in months
        test_months: Test window size in months
    
    Returns:
        DataFrame with validation results per fold
    """
    
    print("\n" + "="*60)
    print("🔬 WALK-FORWARD VALIDATION")
    print("="*60)
    
    results = []
    
    # Convert to time-based indexing
    if 'timestamp' not in df.columns:
        print("ERROR: DataFrame must have 'timestamp' column")
        return pd.DataFrame()
    
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df = df.set_index('timestamp').sort_index()
    
    # Get feature names (assuming FeatureEngineer is available)
    from feature_engineering import FEATURE_LIST_V1
    FEATURES = [f for f in FEATURE_LIST_V1 if f in df.columns]
    
    start_date = df.index.min()
    
    for fold in range(n_splits):
        print(f"\n📊 Fold {fold + 1}/{n_splits}")
        
        # Define train/test periods
        train_end_date = start_date + timedelta(days=30 * train_months * (fold + 1))
        test_start_date = train_end_date
        test_end_date = test_start_date + timedelta(days=30 * test_months)
        
        # Split data
        train_data = df.loc[:train_end_date]
        test_data = df.loc[test_start_date:test_end_date]
        
        if len(test_data) < 100:
            print(f"⚠️  Skipping fold {fold + 1} - insufficient test data")
            continue
        
        print(f"   Train: {len(train_data)} samples ({train_data.index.min()} to {train_data.index.max()})")
        print(f"   Test:  {len(test_data)} samples ({test_data.index.min()} to {test_data.index.max()})")
        
        # Train model on expanding window
        X_train = train_data[FEATURES]
        y_train = train_data['label'] if 'label' in train_data.columns else train_data.iloc[:, -1]
        
        X_test = test_data[FEATURES]
        y_test = test_data['label'] if 'label' in test_data.columns else test_data.iloc[:, -1]
        
        # Scale features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        # Train LightGBM
        model = lgb.LGBMClassifier(
            n_estimators=200,
            learning_rate=0.05,
            max_depth=5,
            num_leaves=31,
            min_child_samples=20,
            subsample=0.8,
            colsample_bytree=0.8,
            random_state=42,
            verbose=-1
        )
        
        model.fit(X_train_scaled, y_train)
        
        # Predict on test set
        y_pred_proba = model.predict_proba(X_test_scaled)[:, 1]
        y_pred = (y_pred_proba >= 0.72).astype(int)
        
        # Calculate metrics
        metrics = {
            'fold': fold + 1,
            'train_size': len(train_data),
            'test_size': len(test_data),
            'train_period': f"{train_data.index.min().date()} to {train_data.index.max().date()}",
            'test_period': f"{test_data.index.min().date()} to {test_data.index.max().date()}",
            'accuracy': accuracy_score(y_test, y_pred),
            'precision': precision_score(y_test, y_pred, zero_division=0),
            'recall': recall_score(y_test, y_pred, zero_division=0),
            'f1_score': f1_score(y_test, y_pred, zero_division=0),
            'roc_auc': roc_auc_score(y_test, y_pred_proba) if len(np.unique(y_test)) > 1 else 0.0
        }
        
        # Calculate trading metrics (simulate trades)
        test_data_copy = test_data.copy()
        test_data_copy['prediction'] = y_pred
        test_data_copy['probability'] = y_pred_proba
        
        trading_metrics = calculate_trading_metrics(test_data_copy)
        metrics.update(trading_metrics)
        
        results.append(metrics)
        
        print(f"   ✅ Accuracy: {metrics['accuracy']:.3f}")
        print(f"   ✅ ROC-AUC: {metrics['roc_auc']:.3f}")
        print(f"   ✅ Sharpe: {metrics.get('sharpe', 0):.3f}")
    
    if not results:
        print("\n⚠️  No validation results generated")
        return pd.DataFrame()
    
    results_df = pd.DataFrame(results)
    
    print("\n" + "="*60)
    print("📊 VALIDATION SUMMARY")
    print("="*60)
    print(results_df.to_string(index=False))
    print("\n📈 Average Metrics:")
    print(f"   Accuracy: {results_df['accuracy'].mean():.3f} ± {results_df['accuracy'].std():.3f}")
    print(f"   ROC-AUC:  {results_df['roc_auc'].mean():.3f} ± {results_df['roc_auc'].std():.3f}")
    
    # Save results
    import os
    os.makedirs('models', exist_ok=True)
    results_df.to_csv('models/walk_forward_results.csv', index=False)
    print("\n💾 Results saved to models/walk_forward_results.csv")
    
    return results_df


def calculate_trading_metrics(df: pd.DataFrame) -> Dict:
    """
    Calculate Sharpe ratio, max drawdown, win rate from predictions (v11)
    
    Args:
        df: DataFrame with 'prediction' and 'probability' columns
        
    Returns:
        Dictionary with trading metrics
    """
    # Simulate trading based on predictions
    df = df.copy()
    df['pnl'] = 0.0
    
    for i in range(len(df)):
        if df['prediction'].iloc[i] == 1:
            # Simulate 30-pip target with 50% win rate assumption
            df.iloc[i, df.columns.get_loc('pnl')] = 30 if np.random.rand() > 0.5 else -20
    
    cumulative_pnl = df['pnl'].cumsum()
    
    # Calculate metrics
    returns = df['pnl']
    sharpe = returns.mean() / returns.std() * np.sqrt(252) if returns.std() > 0 else 0
    
    # Max drawdown
    cummax = cumulative_pnl.cummax()
    drawdown = cumulative_pnl - cummax
    max_dd = drawdown.min()
    
    # Win rate
    trades = df[df['prediction'] == 1]
    win_rate = (trades['pnl'] > 0).sum() / len(trades) if len(trades) > 0 else 0
    
    return {
        'sharpe': sharpe,
        'max_drawdown': max_dd,
        'win_rate': win_rate,
        'total_trades': len(trades),
        'total_pnl': cumulative_pnl.iloc[-1] if len(cumulative_pnl) > 0 else 0
    }


def main():
    """
    Training workflow with walk-forward validation (v11).
    """
    print("=" * 60)
    print("TrendAI v11 Model Training Module")
    print("=" * 60)
    
    # Try to load real historical data
    data_path = os.path.join(os.path.dirname(__file__), 'data', 'usdjpy_m15.csv')
    
    if os.path.exists(data_path):
        print(f"\nLoading real historical data from {data_path}...")
        from collect_data import load_data
        df = load_data(data_path)
        print(f"✓ Loaded {len(df)} candles of real USDJPY M15 data")
    else:
        print("\n⚠️  No historical data found at data/usdjpy_m15.csv")
        print("   Run 'python collect_data.py' first to download real data.")
        print("   Falling back to realistic synthetic data for now...\n")
        from collect_data import generate_realistic_usdjpy
        df = generate_realistic_usdjpy()
    
    # Initialize trainer
    trainer = ModelTrainer(model_type='lightgbm')
    
    # Prepare data
    X, y, df_features = trainer.prepare_data(df)
    
    # Add timestamp for walk-forward validation
    df_features['label'] = y
    df_features = df_features.reset_index()
    
    # Run walk-forward validation (v11)
    print("\n" + "="*60)
    print("Running Walk-Forward Validation...")
    print("="*60)
    wf_results = walk_forward_validation(df_features, n_splits=5, 
                                          train_months=6, test_months=1)
    
    # Check if validation passed
    if len(wf_results) > 0 and wf_results['accuracy'].mean() >= 0.55:
        print("\n✅ Validation passed! Training final model on full dataset...")
        
        # Train with original method
        results = trainer.train_with_walk_forward(X, y, n_splits=5)
        
        # Save model
        trainer.save_model()
        
        print("\n" + "=" * 60)
        print("Training complete!")
        print("=" * 60)
        print("\nNext steps:")
        print("  1. Run export_onnx.py to convert model to ONNX format")
        print("  2. Copy models to MT5 Files folder")
        print("  3. Load EA on USDJPY M15 chart")
    else:
        print("\n⚠️  Validation failed. Model performance insufficient.")
        print("   Average accuracy must be >= 55% to proceed")
        if len(wf_results) > 0:
            print(f"   Actual average accuracy: {wf_results['accuracy'].mean():.3f}")


if __name__ == "__main__":
    main()
