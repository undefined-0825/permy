

# backend ディレクトリに移動し、終了時に必ず元のディレクトリへ戻る
pushd backend
try {
	# 仮想環境を使う場合は有効化（必要に応じてコメントアウトを外してください）
	# . ..\venv\Scripts\Activate.ps1

	# FastAPI（uvicorn）を起動
	uvicorn main:app --reload --host 0.0.0.0 --port 8000
}
finally {
	popd
}
