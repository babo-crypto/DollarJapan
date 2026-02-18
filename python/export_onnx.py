"""
ONNX Export Module for TrendAI v10
===================================

Exports trained LightGBM/XGBoost models to ONNX format for MT5 integration.

Also exports:
- Scaler parameters (means and stds)
- Session configuration
- Model metadata

Author: TrendAI Development Team
Version: 10.0
"""

import pandas as pd
import numpy as np
import pickle
import json
import onnx
import onnxmltools
from onnxconverter_common import FloatTensorType
from skl2onnx import to_onnx
import warnings
warnings.filterwarnings('ignore')


class ONNXExporter:
    """
    Export ML models to ONNX format for MT5.
    """
    
    def __init__(self):
        """Initialize ONNX exporter."""
        self.model = None
        self.scaler_params = None
        self.model_type = None
    
    def load_model(self, model_path: str, model_type: str = 'lightgbm'):
        """
        Load trained model from pickle file.
        
        Args:
            model_path: Path to pickled model
            model_type: 'lightgbm' or 'xgboost'
        """
        with open(model_path, 'rb') as f:
            self.model = pickle.load(f)
        
        self.model_type = model_type
        print(f"✓ Model loaded from {model_path}")
    
    def load_scaler(self, scaler_path: str):
        """
        Load scaler parameters from JSON.
        
        Args:
            scaler_path: Path to scaler JSON file
        """
        with open(scaler_path, 'r') as f:
            self.scaler_params = json.load(f)
        
        print(f"✓ Scaler loaded from {scaler_path}")
    
    def export_lightgbm_to_onnx(self, output_path: str, n_features: int = 14):
        """
        Export LightGBM model to ONNX format.
        
        Args:
            output_path: Output ONNX file path
            n_features: Number of input features
        """
        print(f"\nExporting LightGBM model to ONNX...")
        
        # Define initial types
        initial_type = [('input', FloatTensorType([None, n_features]))]
        
        # Convert to ONNX
        onnx_model = onnxmltools.convert_lightgbm(
            self.model,
            initial_types=initial_type,
            target_opset=12
        )
        
        # Save ONNX model
        onnx.save_model(onnx_model, output_path)
        
        print(f"✓ ONNX model saved to {output_path}")
        
        # Validate the model
        try:
            onnx.checker.check_model(onnx_model)
            print("✓ ONNX model validation passed")
        except Exception as e:
            print(f"⚠ ONNX model validation warning: {e}")
        
        return onnx_model
    
    def export_xgboost_to_onnx(self, output_path: str, n_features: int = 14):
        """
        Export XGBoost model to ONNX format.
        
        Args:
            output_path: Output ONNX file path
            n_features: Number of input features
        """
        print(f"\nExporting XGBoost model to ONNX...")
        
        # Define initial types
        initial_type = [('input', FloatTensorType([None, n_features]))]
        
        # Convert to ONNX
        onnx_model = onnxmltools.convert_xgboost(
            self.model,
            initial_types=initial_type,
            target_opset=12
        )
        
        # Save ONNX model
        onnx.save_model(onnx_model, output_path)
        
        print(f"✓ ONNX model saved to {output_path}")
        
        # Validate the model
        try:
            onnx.checker.check_model(onnx_model)
            print("✓ ONNX model validation passed")
        except Exception as e:
            print(f"⚠ ONNX model validation warning: {e}")
        
        return onnx_model
    
    def export_to_onnx(self, output_path: str, n_features: int = 14):
        """
        Export model to ONNX (auto-detects model type).
        
        Args:
            output_path: Output ONNX file path
            n_features: Number of input features
        """
        if self.model is None:
            raise ValueError("No model loaded. Call load_model() first.")
        
        if self.model_type == 'lightgbm':
            return self.export_lightgbm_to_onnx(output_path, n_features)
        elif self.model_type == 'xgboost':
            return self.export_xgboost_to_onnx(output_path, n_features)
        else:
            raise ValueError(f"Unknown model type: {self.model_type}")
    
    def export_scaler_params(self, output_path: str):
        """
        Export scaler parameters to JSON.
        
        Args:
            output_path: Output JSON file path
        """
        if self.scaler_params is None:
            print("⚠ No scaler parameters loaded")
            return
        
        with open(output_path, 'w') as f:
            json.dump(self.scaler_params, f, indent=2)
        
        print(f"✓ Scaler parameters saved to {output_path}")
    
    def create_session_config(self, output_path: str,
                             optimal_hours: list = None,
                             recommended_sessions: list = None):
        """
        Create session configuration file.
        
        Args:
            output_path: Output JSON file path
            optimal_hours: List of optimal trading hours
            recommended_sessions: List of recommended sessions
        """
        if optimal_hours is None:
            optimal_hours = list(range(8, 24))  # Default: London + NY
        
        if recommended_sessions is None:
            recommended_sessions = ['LONDON', 'NEWYORK']
        
        config = {
            'optimal_hours': optimal_hours,
            'recommended_sessions': recommended_sessions,
            'session_definitions': {
                'ASIA': {'start_hour': 0, 'end_hour': 8},
                'LONDON': {'start_hour': 8, 'end_hour': 16},
                'NEWYORK': {'start_hour': 16, 'end_hour': 24}
            },
            'metadata': {
                'export_date': pd.Timestamp.now().isoformat(),
                'model_type': self.model_type,
                'n_features': 14
            }
        }
        
        with open(output_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✓ Session config saved to {output_path}")
    
    def export_all(self, output_dir: str = '../models',
                  model_name: str = 'trendai_v10'):
        """
        Export all files needed for MT5 integration.
        
        Args:
            output_dir: Output directory
            model_name: Base name for output files
        """
        import os
        os.makedirs(output_dir, exist_ok=True)
        
        print("=" * 60)
        print("Exporting TrendAI v10 Model for MT5")
        print("=" * 60)
        
        # Export ONNX model
        onnx_path = f'{output_dir}/{model_name}.onnx'
        self.export_to_onnx(onnx_path)
        
        # Export scaler
        scaler_path = f'{output_dir}/scaler.json'
        self.export_scaler_params(scaler_path)
        
        # Create session config
        session_path = f'{output_dir}/session_config.json'
        self.create_session_config(session_path)
        
        print("\n" + "=" * 60)
        print("Export complete!")
        print("=" * 60)
        print("\nGenerated files:")
        print(f"  1. {onnx_path}")
        print(f"  2. {scaler_path}")
        print(f"  3. {session_path}")
        print("\nNext steps:")
        print("  1. Copy these files to your MT5 MQL5/Files/models/ directory")
        print("  2. Load TrendAI_v10.mq5 EA on USDJPY M15 chart")
        print("  3. Verify that the EA loads the ONNX model successfully")


def main():
    """
    Auto-detect and export trained models to ONNX.
    """
    import os
    
    print("=" * 60)
    print("TrendAI v10 ONNX Export Module")
    print("=" * 60)
    
    # Define base directory (relative to this script)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    models_dir = os.path.join(script_dir, '..', 'models')
    models_dir = os.path.abspath(models_dir)
    
    # Auto-detect model file (try lightgbm first, then xgboost)
    model_path = None
    model_type = None
    
    lgb_path = os.path.join(models_dir, 'trendai_v10_lgb.pkl')
    xgb_path = os.path.join(models_dir, 'trendai_v10_xgb.pkl')
    
    if os.path.exists(lgb_path):
        model_path = lgb_path
        model_type = 'lightgbm'
        print(f"\n✓ Found LightGBM model: {lgb_path}")
    elif os.path.exists(xgb_path):
        model_path = xgb_path
        model_type = 'xgboost'
        print(f"\n✓ Found XGBoost model: {xgb_path}")
    
    # Auto-detect scaler file
    scaler_path = os.path.join(models_dir, 'scaler.json')
    scaler_exists = os.path.exists(scaler_path)
    
    if scaler_exists:
        print(f"✓ Found scaler: {scaler_path}")
    else:
        print(f"⚠ Scaler not found: {scaler_path}")
    
    # If model exists, perform export
    if model_path and scaler_exists:
        print("\n" + "=" * 60)
        print("Starting automatic export...")
        print("=" * 60)
        
        try:
            # Create exporter
            exporter = ONNXExporter()
            
            # Load model
            exporter.load_model(model_path, model_type=model_type)
            
            # Load scaler
            exporter.load_scaler(scaler_path)
            
            # Export all files
            exporter.export_all(output_dir=models_dir, model_name='trendai_v10')
            
            print("\n✓ Export completed successfully!")
            return
            
        except Exception as e:
            print(f"\n✗ Export failed: {e}")
            import traceback
            traceback.print_exc()
            return
    
    # If files don't exist, show usage instructions
    print("\n" + "=" * 60)
    print("Model or scaler files not found!")
    print("=" * 60)
    
    print("\nPrerequisites:")
    print("  1. Trained model saved as pickle file")
    print("  2. Scaler parameters saved as JSON")
    print("  3. Required packages: onnx, onnxmltools, skl2onnx")
    
    print("\nExpected files:")
    print(f"  - Model: {lgb_path}")
    print(f"    OR:    {xgb_path}")
    print(f"  - Scaler: {scaler_path}")
    
    print("\nManual Usage:")
    print("-" * 60)
    print("""
# Load and export model
exporter = ONNXExporter()

# Load trained model
exporter.load_model('models/trendai_v10_lgb.pkl', model_type='lightgbm')

# Load scaler
exporter.load_scaler('models/scaler.json')

# Export all files
exporter.export_all(output_dir='models', model_name='trendai_v10')
    """)
    
    print("\n" + "=" * 60)
    print("Note: Run train_model.py first to generate the model files.")
    print("=" * 60)


if __name__ == "__main__":
    main()
