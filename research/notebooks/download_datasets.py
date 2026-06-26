#!/usr/bin/env python3
"""
Download Kaggle datasets using API token authentication.
"""
import os
import sys
import requests
import zipfile
import io

API_TOKEN = "KGAT_6257fefd02813d6c262cf55e772941a9"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASETS_DIR = os.path.join(BASE_DIR, '..', 'datasets')

DATASETS = {
    'smart_home': 'pythonafroz/smart-home-dataset',
    'hvac_power': 'felixpradoh/hvac-system-power-consumption-and-sensor-data',
    'water_leak': 'ziya07/water-leak-dataset',
    # New datasets (v3)
    'nasa_cmapss': 'behrad3d/nasa-cmaps',
    'smoke_detection': 'deepcontractor/smoke-detection-dataset',
    'electrical_fault': 'esathyaprakash/electrical-fault-detection-and-classification',
}

def download_dataset(slug, local_name):
    """Download a Kaggle dataset using the API token."""
    local_dir = os.path.join(DATASETS_DIR, local_name)
    os.makedirs(local_dir, exist_ok=True)
    
    # Check if already has CSV files
    existing = [f for f in os.listdir(local_dir) if f.endswith(('.csv', '.txt', '.parquet'))]
    if existing:
        print(f"  ✓ {local_name} already has {len(existing)} CSV files")
        return True
    
    url = f"https://www.kaggle.com/api/v1/datasets/download/{slug}"
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
    }
    
    print(f"  ↓ Downloading {slug}...")
    try:
        resp = requests.get(url, headers=headers, stream=True, timeout=120)
        
        if resp.status_code == 401:
            print(f"  ✗ Authentication failed. Token may be invalid.")
            return False
        elif resp.status_code == 403:
            print(f"  ✗ Forbidden. May need to accept dataset terms on Kaggle website first.")
            return False
        elif resp.status_code != 200:
            print(f"  ✗ HTTP {resp.status_code}: {resp.text[:200]}")
            return False
        
        # Save zip to disk
        zip_path = os.path.join(local_dir, f"{local_name}.zip")
        total = 0
        with open(zip_path, 'wb') as f:
            for chunk in resp.iter_content(chunk_size=8192):
                f.write(chunk)
                total += len(chunk)
        
        print(f"    Downloaded {total / 1024 / 1024:.1f} MB")
        
        # Unzip
        try:
            with zipfile.ZipFile(zip_path, 'r') as z:
                z.extractall(local_dir)
            os.remove(zip_path)
            print(f"  ✓ {local_name} extracted successfully")
        except zipfile.BadZipFile:
            print(f"  ✗ Not a valid zip file. The download may have failed.")
            os.remove(zip_path)
            return False
        
        return True
    except requests.exceptions.Timeout:
        print(f"  ✗ Download timed out after 120 seconds")
        return False
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False


if __name__ == '__main__':
    print("=" * 60)
    print("Kaggle Dataset Downloader")
    print("=" * 60)
    
    success = 0
    for local_name, slug in DATASETS.items():
        if download_dataset(slug, local_name):
            success += 1
    
    print(f"\n{success}/{len(DATASETS)} datasets downloaded successfully")
    
    # List what we got
    for local_name in DATASETS:
        local_dir = os.path.join(DATASETS_DIR, local_name)
        if os.path.exists(local_dir):
            files = os.listdir(local_dir)
            print(f"  {local_name}/: {files}")
