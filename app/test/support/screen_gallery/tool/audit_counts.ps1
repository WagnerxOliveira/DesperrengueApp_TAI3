# Contagens reproduziveis da auditoria v2.28.0 (fora de features/founder).
#
# Uso (a partir de app/):
#   powershell -NoProfile -File test/support/screen_gallery/tool/audit_counts.ps1            # resumo
#   powershell -NoProfile -File test/support/screen_gallery/tool/audit_counts.ps1 -Markdown  # + tabela por arquivo (onda/dono)
#   powershell -NoProfile -File test/support/screen_gallery/tool/audit_counts.ps1 -Csv out.csv
#
# Metodologia: regex sobre o texto de cada .dart em lib/ (sem features/founder/** e sem
# main_founder.dart). "fora de core/" exclui lib/core/**. Colunas "spec" da secao 1.1 do
# prompt mestre foram medidas COM founder em varias linhas (ver relatorio).
param([string]$Csv = '', [switch]$Markdown)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$lib = Join-Path $root 'lib'
$files = Get-ChildItem $lib -Recurse -Filter *.dart |
  Where-Object { $_.FullName -notmatch '[\\/]features[\\/]founder[\\/]' -and $_.Name -ne 'main_founder.dart' }

$patterns = [ordered]@{
  fontSize        = 'fontSize\s*:'
  fontSizeNum     = 'fontSize\s*:\s*\d'
  colorLiteral    = 'Color\(\s*0x'
  contextTk       = 'context\.tk\b'
  materialRoute   = 'MaterialPageRoute'
  bottomSheet     = 'showModalBottomSheet'
  dialog          = 'showDialog'
  spinner         = 'CircularProgressIndicator'
  fittedBox       = 'FittedBox'
  ellipsis        = 'TextOverflow\.ellipsis'
  isCompact       = 'isCompact'
  animSwitch      = 'AnimatedSwitcher|AnimatedContainer|AnimatedOpacity'
  layoutBuilder   = 'LayoutBuilder'
  colorsDot       = 'Colors\.(?!transparent|white|black)\w+'
  fontWeightW8_9  = 'FontWeight\.w[89]00'
  fontFamilyLit   = 'fontFamily\s*:'
  repeatAnim      = '\.repeat\('
}

# Onda (spec 5) e dono sugerido por arquivo (regex sobre o caminho relativo a lib/).
$waveMap = @(
  @('^features/boot/', 1, 'auth_ui'),
  @('^features/auth/presentation/widgets/cinema_|desperrengue_welcome_cinema_screen|story_nav_circle', 0, '(pronto v2.27.0)'),
  @('^features/auth/', 1, 'auth_ui'),
  @('role_terms_acceptance_screen|criminal_background_check_step', 1, 'auth_ui'),
  @('client_shell|provider_search_screen|category_picker|request_wizard|smart_triage_widgets|voice_dictation|address_form|published_overlay', 2, 'client_core_ui'),
  @('client_orders_tab|client_job_screen|detalhe_servico_cliente|order_tracking_screen|completion_screens|historico_servicos_cliente|provider_public_profile', 3, 'client_orders_ui'),
  @('carteira_cliente|adicionar_saldo|insufficient_funds|payment_widgets|wallet_chip|client_setup_screen', 3, 'client_core_ui'),
  @('^features/provider/', 4, 'provider_ui'),
  @('^features/shared/', 5, 'shared_ui'),
  @('^features/home/', 5, 'shared_ui'),
  @('^core/ui/', 5, 'foundation'),
  @('^main\.dart', 0, 'foundation')
)
function Wave-Of($rel) {
  foreach ($w in $waveMap) { if ($rel -match $w[0]) { return @($w[1], $w[2]) } }
  return @('-', '-')
}
function Count-Matches($text, $rx) { ([regex]::Matches($text, $rx)).Count }

$rows = foreach ($f in $files) {
  $text = Get-Content $f.FullName -Raw -Encoding UTF8
  $rel = $f.FullName.Substring($lib.Length + 1).Replace('\', '/')
  $o = [ordered]@{ file = $rel; lines = (($text -split "`n").Count - 1) }
  foreach ($k in $patterns.Keys) { $o[$k] = Count-Matches $text $patterns[$k] }
  $small = 0
  foreach ($m in [regex]::Matches($text, 'fontSize\s*:\s*(\d+(?:\.\d+)?)')) { if ([double]$m.Groups[1].Value -lt 12) { $small++ } }
  $o['fontSizeLt12'] = $small
  $wv = Wave-Of $rel
  $o['wave'] = $wv[0]; $o['owner'] = $wv[1]
  [pscustomobject]$o
}

$scope = $rows | Where-Object { $_.file -match '^features/(client|provider|shared|home)/' }
$outsideCore = $rows | Where-Object { $_.file -notmatch '^core/' }
$totalLines = ($rows | Measure-Object lines -Sum).Sum
"Arquivos Dart (sem founder): $($rows.Count) | linhas: $totalLines"
"{0,-18}{1,16}{2,16}{3,22}" -f 'indicador', 'total s/founder', 'fora de core/', 'cli+prov+shared+home'
foreach ($k in ($patterns.Keys + 'fontSizeLt12')) {
  "{0,-18}{1,16}{2,16}{3,22}" -f $k, (($rows | Measure-Object $k -Sum).Sum), (($outsideCore | Measure-Object $k -Sum).Sum), (($scope | Measure-Object $k -Sum).Sum)
}
"Testes (*_test.dart em test/): $((Get-ChildItem (Join-Path $root 'test') -Recurse -Filter *_test.dart).Count) | goldens (png em test/): $((Get-ChildItem (Join-Path $root 'test') -Recurse -Filter *.png -ErrorAction SilentlyContinue).Count)"

if ($Markdown) {
  ''
  '| arquivo | linhas | fontSize | <12 | Color(0x | Colors.* | FittedBox | ellipsis | spinner | MaterialPageRoute | sheet/dialog | w800/900 | onda | dono |'
  '|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|:-:|---|'
  foreach ($r in ($rows | Where-Object { $_.file -match '^(features|main\.dart|core/ui)' } | Sort-Object @{e={[string]$_.wave}}, file)) {
    '| `{0}` | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} |' -f $r.file, $r.lines, $r.fontSizeNum, $r.fontSizeLt12, $r.colorLiteral, $r.colorsDot, $r.fittedBox, $r.ellipsis, $r.spinner, $r.materialRoute, ($r.bottomSheet + $r.dialog), $r.fontWeightW8_9, $r.wave, $r.owner
  }
}
if ($Csv) { $rows | Export-Csv -NoTypeInformation -Encoding UTF8 $Csv; "CSV -> $Csv" }
