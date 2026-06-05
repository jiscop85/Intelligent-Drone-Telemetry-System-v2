#!/usr/bin/env python3
"""Train Anomaly Detection Model
Train IsolationForest model on known-good flight CSV data
"""

from pathlib import Path
import sys
from anomaly_detector import AnomalyDetector

def train_model(csv_path: str, output_model_path: str = "data/models/anomaly.joblib", contamination: float = 0.02):
    """Train and save the anomaly detection model"""
    print(f"Loading training data from {csv_path}...")
    if not Path(csv_path).exists():
        raise FileNotFoundError(f"Training data file not found: {csv_path}")
    
    detector = AnomalyDetector(model_path=output_model_path)
    
    print(f"Training IsolationForest model (contamination={contamination})...")
    detector.train_from_csv(csv_path, contamination=contamination)
    
    print(f"Model saved to {output_model_path}")
    print("Training complete!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python train_model.py <training_data.csv> [output_model.joblib] [contamination]")
        print("  training_data.csv: CSV file with known-good flight data")
        print("  output_model.joblib: Path to save trained model (default: data/models/anomaly.joblib)")
        print("  contamination: Expected anomaly rate (default: 0.02)")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "data/models/anomaly.joblib"
    contamination = float(sys.argv[3]) if len(sys.argv) > 3 else 0.02
    
    try:
        train_model(csv_path, output_path, contamination)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
