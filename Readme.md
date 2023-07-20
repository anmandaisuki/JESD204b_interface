

## 使う前に確認してほしいこと
* "clean.bat" "recreate_proj.bat" "create_proj_template.tcl" ファイル内のProject_Name変数が一致していること。  

## 使い方
* git(hub) には、project作成に必要なソースのみ管理するようにして、ソースからprojectを再生成できるようにしてある。
* 開発段階を想定しているので、ブロックデザインは考慮せずRTLソースとIP(.xci),テストベンチソース,制約ファイル(.xdc)のみを管理するようにし、そこからプロジェクトを再生成する。

1. git clone ...　でこのリポジトリをclone
2. recreate_proj.batでソースからプロジェクトを再生成。ソースをそのまま編集するのであれば、プロジェクトを再合成する必要なし。
3. プロジェクトを編集
    * 新しくソース・ファイルやIPを追加するときはsrcディレクトリに格納すること。
    * すでに存在するソース・ファイルを編集するときもsrcディレクトリに存在するものを編集すること。
4. clean.bat　でソースファイル以外を削除する。(recreate_proj.batでソースからプロジェクトは再生成できる)
5. git add > git commit > git pushで変更を更新する。

## srcディレクトリの構成
* src : RTLソース(.v, .sv, .vh)格納フォルダ
* src/ip : IP(.xci)格納フォルダ
* src/sim : テストベンチ用RTL(.v, .sv, .vh)格納フォルダ
* src/const : 制約ファイル格納フォルダ

* tclコマンドでのファイル検索が検索ディレクトリの中にフォルダがあるとめんどくさかったので、基本的にはディレクトリの中にフォルダは作らず、そのままソース・ファイルを格納していく。Vivadoプロジェクト上で自動で依存関係とか調整してくれるので、問題ないと思う。。。


## 各ファイル/フォルダの説明
* clean.bat : vivadoでprojectを再生成するときに作られるログ・ファイルやプロジェクトファイルを削除する。
* recreate_proj.bat : 内部でcreate_proj_template.tclを呼び出して、projectを再生成する。
* create_proj_template.tcl : 直接は起動しない。recreate_proj.batによって起動される。
* src : RTLソースやIPソース

