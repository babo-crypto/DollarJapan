//+------------------------------------------------------------------+
//|                                                  onnx_runner.mqh |
//|                                      TrendAI_v10 ONNX Inference  |
//|                           Institutional-Grade ML Inference Layer |
//+------------------------------------------------------------------+
//| Module: ONNX Inference Engine                                     |
//| Purpose: Load ONNX model and run predictions                     |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property version   "10.0"
#property strict

#include <Math\Stat\Math.mqh>

//+------------------------------------------------------------------+
//| ONNX Runner Class                                                 |
//+------------------------------------------------------------------+
class CONNXRunner
{
private:
   long     m_model_handle;
   bool     m_model_loaded;
   string   m_model_path;
   
   // Scaler parameters (loaded from scaler.json)
   double   m_feature_means[14];
   double   m_feature_stds[14];
   bool     m_scaler_loaded;
   
   // Model metadata
   int      m_num_features;
   datetime m_model_load_time;
   
   // Performance tracking
   int      m_inference_count;
   double   m_avg_inference_time_ms;
   
   //--- Private methods
   bool     LoadScaler(string scaler_path);
   void     NormalizeFeatures(double &features[]);
   bool     ValidateFeatures(const double &features[]);
   
public:
   //--- Constructor / Destructor
   CONNXRunner();
   ~CONNXRunner();
   
   //--- Initialization
   bool     LoadModel(string model_path, string scaler_path);
   void     UnloadModel();
   
   //--- Inference
   double   Predict(double &features[]);
   bool     IsModelLoaded() { return m_model_loaded; }
   
   //--- Diagnostics
   int      GetInferenceCount() { return m_inference_count; }
   double   GetAvgInferenceTime() { return m_avg_inference_time_ms; }
   datetime GetModelLoadTime() { return m_model_load_time; }
   string   GetModelPath() { return m_model_path; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CONNXRunner::CONNXRunner()
{
   m_model_handle = INVALID_HANDLE;
   m_model_loaded = false;
   m_model_path = "";
   m_scaler_loaded = false;
   m_num_features = 14;
   m_model_load_time = 0;
   m_inference_count = 0;
   m_avg_inference_time_ms = 0.0;
   
   ArrayInitialize(m_feature_means, 0.0);
   ArrayInitialize(m_feature_stds, 1.0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CONNXRunner::~CONNXRunner()
{
   UnloadModel();
}

//+------------------------------------------------------------------+
//| Load ONNX model and scaler                                       |
//+------------------------------------------------------------------+
bool CONNXRunner::LoadModel(string model_path, string scaler_path)
{
   Print("Loading ONNX model from: ", model_path);
   
   // Check if file exists
   if(!FileIsExist(model_path))
   {
      Print("ERROR: ONNX model file not found: ", model_path);
      Print("Please run Python training scripts to generate the model.");
      return false;
   }
   
   // Load the ONNX model
   m_model_handle = OnnxCreateFromFile(model_path, ONNX_DEFAULT);
   
   if(m_model_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to load ONNX model. Error code: ", GetLastError());
      return false;
   }
   
   m_model_path = model_path;
   m_model_loaded = true;
   m_model_load_time = TimeCurrent();
   
   Print("ONNX model loaded successfully. Handle: ", m_model_handle);
   
   // Load scaler parameters
   if(!LoadScaler(scaler_path))
   {
      Print("WARNING: Scaler not loaded. Using raw features (not recommended).");
      // Continue anyway - model might work without normalization
   }
   else
   {
      Print("Scaler loaded successfully from: ", scaler_path);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Unload ONNX model                                                |
//+------------------------------------------------------------------+
void CONNXRunner::UnloadModel()
{
   if(m_model_handle != INVALID_HANDLE)
   {
      OnnxRelease(m_model_handle);
      m_model_handle = INVALID_HANDLE;
      Print("ONNX model unloaded");
   }
   m_model_loaded = false;
}

//+------------------------------------------------------------------+
//| Load scaler parameters from JSON file                            |
//+------------------------------------------------------------------+
bool CONNXRunner::LoadScaler(string scaler_path)
{
   if(!FileIsExist(scaler_path))
   {
      Print("WARNING: Scaler file not found: ", scaler_path);
      return false;
   }
   
   int file_handle = FileOpen(scaler_path, FILE_READ|FILE_TXT|FILE_ANSI);
   if(file_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to open scaler file: ", scaler_path);
      return false;
   }
   
   // Read entire file content
   string json_content = "";
   while(!FileIsEnding(file_handle))
   {
      json_content += FileReadString(file_handle);
   }
   FileClose(file_handle);
   
   // Parse JSON manually (simple parsing for our specific format)
   // Expected format: {"means": [...], "stds": [...]}
   
   // Extract means array
   int means_start = StringFind(json_content, "\"means\"");
   if(means_start >= 0)
   {
      int bracket_start = StringFind(json_content, "[", means_start);
      int bracket_end = StringFind(json_content, "]", bracket_start);
      
      if(bracket_start >= 0 && bracket_end > bracket_start)
      {
         string means_str = StringSubstr(json_content, bracket_start + 1, bracket_end - bracket_start - 1);
         
         // Parse comma-separated values
         string means_values[];
         int means_count = StringSplit(means_str, ',', means_values);
         
         for(int i = 0; i < MathMin(means_count, 14); i++)
         {
            StringTrimLeft(means_values[i]);
            StringTrimRight(means_values[i]);
            m_feature_means[i] = StringToDouble(means_values[i]);
         }
      }
   }
   
   // Extract stds array
   int stds_start = StringFind(json_content, "\"stds\"");
   if(stds_start >= 0)
   {
      int bracket_start = StringFind(json_content, "[", stds_start);
      int bracket_end = StringFind(json_content, "]", bracket_start);
      
      if(bracket_start >= 0 && bracket_end > bracket_start)
      {
         string stds_str = StringSubstr(json_content, bracket_start + 1, bracket_end - bracket_start - 1);
         
         // Parse comma-separated values
         string stds_values[];
         int stds_count = StringSplit(stds_str, ',', stds_values);
         
         for(int i = 0; i < MathMin(stds_count, 14); i++)
         {
            StringTrimLeft(stds_values[i]);
            StringTrimRight(stds_values[i]);
            m_feature_stds[i] = StringToDouble(stds_values[i]);
            
            // Prevent division by zero
            if(m_feature_stds[i] < 0.00001)
               m_feature_stds[i] = 1.0;
         }
      }
   }
   
   m_scaler_loaded = true;
   return true;
}

//+------------------------------------------------------------------+
//| Normalize features using loaded scaler                           |
//+------------------------------------------------------------------+
void CONNXRunner::NormalizeFeatures(double &features[])
{
   if(!m_scaler_loaded)
      return;
   
   int count = ArraySize(features);
   for(int i = 0; i < count && i < 14; i++)
   {
      features[i] = (features[i] - m_feature_means[i]) / m_feature_stds[i];
   }
}

//+------------------------------------------------------------------+
//| Validate feature vector                                          |
//+------------------------------------------------------------------+
bool CONNXRunner::ValidateFeatures(const double &features[])
{
   int count = ArraySize(features);
   
   if(count != m_num_features)
   {
      Print("ERROR: Invalid feature count. Expected: ", m_num_features, ", Got: ", count);
      return false;
   }
   
   // Check for NaN or Inf values
   for(int i = 0; i < count; i++)
   {
      if(!MathIsValidNumber(features[i]))
      {
         Print("ERROR: Invalid feature value at index ", i, ": ", features[i]);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Run inference and return prediction probability                  |
//+------------------------------------------------------------------+
double CONNXRunner::Predict(double &features[])
{
   if(!m_model_loaded)
   {
      Print("ERROR: Model not loaded. Cannot run inference.");
      return 0.0;
   }
   
   // Validate input features
   if(!ValidateFeatures(features))
   {
      return 0.0;
   }
   
   // Start timing
   uint start_time = GetTickCount();
   
   // Create a copy for normalization
   double normalized_features[];
   ArrayResize(normalized_features, ArraySize(features));
   ArrayCopy(normalized_features, features);
   
   // Normalize features
   NormalizeFeatures(normalized_features);
   
   // Prepare input matrix for ONNX (shape: [1, num_features])
   matrix input_matrix;
   input_matrix.Init(1, m_num_features);
   
   for(int i = 0; i < m_num_features; i++)
   {
      input_matrix[0][i] = normalized_features[i];
   }
   
   // Prepare output matrix
   matrix output_matrix;
   
   // Run ONNX inference
   if(!OnnxRun(m_model_handle, ONNX_DEFAULT, input_matrix, output_matrix))
   {
      Print("ERROR: ONNX inference failed. Error code: ", GetLastError());
      return 0.0;
   }
   
   // Calculate inference time
   uint end_time = GetTickCount();
   double inference_time = (double)(end_time - start_time);
   
   // Update performance metrics
   m_inference_count++;
   m_avg_inference_time_ms = (m_avg_inference_time_ms * (m_inference_count - 1) + inference_time) / m_inference_count;
   
   // Extract prediction probability
   // For binary classification: output should be shape [1, 2] or [1, 1]
   double probability = 0.0;
   
   if(output_matrix.Cols() == 2)
   {
      // Two-class output: take the positive class probability
      probability = output_matrix[0][1];
   }
   else if(output_matrix.Cols() == 1)
   {
      // Single output: direct probability
      probability = output_matrix[0][0];
   }
   else
   {
      Print("WARNING: Unexpected output shape from ONNX model");
      probability = output_matrix[0][0];
   }
   
   // Clamp probability to [0, 1]
   if(probability < 0.0)
      probability = 0.0;
   if(probability > 1.0)
      probability = 1.0;
   
   return probability;
}
//+------------------------------------------------------------------+
