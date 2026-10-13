# Clear an Alire environment inherited from an older editor session.
Get-ChildItem Env: | Where-Object { $_.Name -eq 'ALIRE' -or $_.Name -like '*_ALIRE_PREFIX' } | ForEach-Object {
   Remove-Item -LiteralPath ("Env:" + $_.Name)
}
