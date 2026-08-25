# Bundle the application source for distribution (excludes runtime scratch,
# benchmarks, and the externally-supplied organism references).
zip -r preditr.zip app_info.yaml .dockerignore *.sh *.R *.dockerfile \
  LICENSE README.md functions/ run/ www/
