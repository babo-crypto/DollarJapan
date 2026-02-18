"""
Model Training Module for TrendAI v10
======================================

Trains LightGBM/XGBoost models with:
- Walk-forward validation
- Hyperparameter tuning
- Feature importance analysis
- Broker hour analytics
- Model performance evaluation

Author: TrendAI Development Team
Version: 10.0
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
from datetime import datetime
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


def main():
    """
    Example training workflow.
    """
    print("=" * 60)
    print("TrendAI v10 Model Training Module")
    print("=" * 60)
    
    # Note: This is an example. In production, load real historical data
    print("\nNote: This example uses synthetic data.")
    print("In production, load real USDJPY M15 historical data.")
    
    # Create synthetic data
    dates = pd.date_range('2024-01-01', periods=10000, freq='15T')
    np.random.seed(42)
    
    base_price = 150.0
    price_changes = np.cumsum(np.random.randn(10000) * 0.01)
    
    df = pd.DataFrame({
        'timestamp': dates,
        'open': base_price + price_changes,
        'high': base_price + price_changes + np.abs(np.random.randn(10000) * 0.02),
        'low': base_price + price_changes - np.abs(np.random.randn(10000) * 0.02),
        'close': base_price + price_changes,
        'tick_volume': np.random.randint(100, 1000, 10000),
        'spread': np.random.uniform(0.5, 3.0, 10000)
    })
    
    # Initialize trainer
    trainer = ModelTrainer(model_type='lightgbm')
    
    # Prepare data
    X, y, df_features = trainer.prepare_data(df)
    
    # Train with walk-forward validation
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


if __name__ == "__main__":
    main()
