

# backend ディレクトリに移動し、終了時に必ず元のディレクトリへ戻る
Push-Location backend
try {
	$root = $PSScriptRoot
	$venvPython = Join-Path $root ".venv\Scripts\python.exe"

	if (-not (Test-Path $venvPython)) {
		throw ".venv の Python が見つかりません: $venvPython"
	}

	$pythonCmd = $venvPython
	Write-Host "Using venv Python: $pythonCmd"

	# 起動前に必ずテーブルを作成（users等の欠損を防ぐ）
	& $pythonCmd init_db_simple.py

	# FastAPI（uvicorn）を起動（DB初期化と同一Python環境を使用）
	& $pythonCmd -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
}
finally {
	Pop-Location
}
