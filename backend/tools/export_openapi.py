"""
OpenAPI specification をファイルに出力
Usage: python tools/export_openapi.py
"""
import json
import sys
from pathlib import Path

# backend/ をカレントディレクトリとして実行されることを想定
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.main import app

def export_openapi(output_path: str = "../docs/api/openapi.json"):
    """FastAPI の OpenAPI スキーマを JSON ファイルに出力"""
    
    openapi_schema = app.openapi()
    
    # 出力先ディレクトリを作成
    output_file = Path(__file__).parent.parent / output_path
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    # JSON として整形して出力
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(openapi_schema, f, indent=2, ensure_ascii=False)
    
    print(f"[OK] OpenAPI schema exported to: {output_file.resolve()}")
    print(f"     - Title: {openapi_schema.get('info', {}).get('title')}")
    print(f"     - Version: {openapi_schema.get('info', {}).get('version')}")
    print(f"     - Paths: {len(openapi_schema.get('paths', {}))}")
    print(f"     - Schemas: {len(openapi_schema.get('components', {}).get('schemas', {}))}")

if __name__ == "__main__":
    export_openapi()
