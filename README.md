# DaVinci Resolve Scripts

DaVinci Resolve のスクリプトおよびプラグイン開発用リポジトリです。
Python/Lua スクリプト群は Junction による直接リンクでコピー不要の開発環境を提供し、高度な Workflow Integration (Electron等) プラグイン群は Vite を用いた直接デプロイシステムを提供します。

## ディレクトリ構成

- `src/`: 開発するソースコード
  - `Scripts/`: Python/Lua スクリプト
    - `Utility/`, `Edit/`, `Color/`, `Deliver/`: 各ページごとのスクリプト配置用
  - `Workflow_Integration/`: ワークフロー統合プラグイン（Electron等）
- `Developer/`: DaVinci Resolve 公式 SDK へのリンク（`setup.ps1` で作成）
  - API ドキュメントやサンプルコードが含まれており、LLM (AI) や開発者が参照するために利用します。
- `setup.ps1`: 環境構築スクリプト（Junction の作成）

## セットアップ

### 1. 開発環境の構築（インストール）

`install.bat` をダブルクリックして実行してください。
（管理者権限の要求が表示されるので「はい」を選択してください。ドライブを跨いだリンクを作成するため、シンボリックリンクの作成に管理者権限が必要です）

コマンドラインから実行する場合は以下：
```powershell
.\install.bat
```

このスクリプトを実行すると、以下の処理が自動で行われます：
1. **SDK 参照の作成**: 公式の `Developer` フォルダをリポジトリ内にシンボリックリンクします。
2. **スクリプトのリンク**: `src/Scripts` 以下の各機能フォルダ（`Utility`, `Edit`など）を Resolve の該当ページ用フォルダ内に `MyScripts` という名前でそれぞれ個別にシンボリックリンクします。

※ **プラグイン（Workflow Integration）について**:
DaVinci Resolve の Workflow Integration ではジャンクション（シンボリックリンク）を介したファイルロードが厳格にアクセス制限され、プラグインが正常に動作しない仕様となっています。
そのため、`src/Workflow_Integration/` 内のプラグイン（例: `SubtitleMarkdownEditor`）はリンクを作成せず、個別の Vite ビルドシステムを用いて DaVinci Resolve の `%PROGRAMDATA%` ディレクトリへ直接ビルド出力します（詳しくは各プラグインの `README.md` をご覧ください）。

### 2. 反映の確認

1. DaVinci Resolve を起動します。
2. **スクリプト**: メニューの `Workspace` > `Scripts` > `MyScripts` 内に、スクリプトが表示されます。

## 開発のヒント

- **ドライブ跨ぎ対応**: シンボリックリンクを使用しているため、プロジェクトを D: ドライブに置き、Resolve の設定を C: ドライブに置くといった構成でも問題なく動作します。
- **即時反映**: リンクを使用しているため、リポジトリ内のファイルを編集して保存するだけで、即座に Resolve 側に反映されます。
- **AI 活用**: `Developer/` ディレクトリがリンクされているため、AI アシスタントに対して「`Developer/Scripting/README.txt` を参考にしてスクリプトを書いて」といった指示が容易になります。
- **【重要】CLIからの直接実行・テスト**: Resolve が起動中であれば、GUIを使わずにコマンドラインから直接短いスクリプトを送り込んでテストやデバッグを実行し、結果（ログなど）を取得できます。
  - 具体的なコマンド例は以下の通りです。AIエージェントに「以下のコマンド例を参考にシェルで実行してAPIの仕様を確かめて」と指示することで、確実な実装が可能になります。
  - **Luaの実行例 (`fuscript.exe`)**:
    ```powershell
    & "C:\Program Files\Blackmagic Design\DaVinci Resolve\fuscript.exe" -x "local resolve = Resolve(); print(resolve:GetProjectManager():GetCurrentProject():GetName())"
    ```
  - **Pythonの実行例**:
    ```powershell
    $env:PYTHONPATH = "$env:PROGRAMDATA\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting\Modules\"; python -c "import DaVinciResolveScript as dvr_script; resolve = dvr_script.scriptapp('Resolve'); print(resolve.GetProjectManager().GetCurrentProject().GetName())"
    ```
- **ディレクトリ階層**: `src/Scripts/Utility/` に置いたスクリプトは Resolve のすべてのページで表示されます。特定のページでのみ使いたい場合は、それぞれのページ名フォルダに配置してください。

## アンインストール

セットアップしたリンクを削除して元の状態に戻すには、`uninstall.bat` を実行してください。
（セットアップ時と同様、リンクの削除に管理者権限が必要です）
