#!/usr/bin/env python3
"""Anomaly Detection for Drone Telemetry
Train on known-good flight data and score live samples
"""

from pathlib import Path
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest

FEATURES = ["rel_alt_m", "battery_pct", "ground_speed_mps", "temp_c", "wind_speed_mps"]

class AnomalyDetector:
    def __init__(self, model_path: str = "data/models/anomaly.joblib"):
        self.model_path = Path(model_path)
        self.model = joblib.load(self.model_path) if self.model_path.exists() else None

    def train_from_csv(self, csv_path: str, contamination: float = 0.02):
        """Train model from CSV file of known-good flights"""
        df = pd.read_csv(csv_path)
        X = df[FEATURES].replace([np.inf, -np.inf], np.nan).dropna()
        model = IsolationForest(
            n_estimators=300,
            contamination=contamination,
            random_state=42
        )
        model.fit(X)
        joblib.dump(model, self.model_path)
        self.model = model

    def score(self, sample: dict) -> str:
        """Score a telemetry sample for anomalies"""
        values = [sample.get(k) for k in FEATURES]
        if any(v is None for v in values):
            return "insufficient data"

        x = np.array(values, dtype=float).reshape(1, -1)

        if self.model is None:
            # Fallback heuristics if no model trained
            if sample.get("battery_pct", 100) < 15:
                return "warning: low battery"
            if abs(sample.get("ground_speed_mps", 0) or 0) > 40:
                return "warning: high speed"
            return "normal"

        pred = self.model.predict(x)[0]
        return "anomaly" if pred == -1 else "normal"
