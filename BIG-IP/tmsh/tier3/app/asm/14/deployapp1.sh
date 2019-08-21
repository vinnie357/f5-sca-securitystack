#!/usr/bin/bash
# partition
partition="app1"
# app name
appName="app1"
# tag
appTag="AppName"
# nodes
node1="5.6.7.8"
# virtual addresss
virtualAddress="9.10.11.1"
# asm policy
asmPolicy="app1"
asmFile="/config/owasp-auto-tune.xml"
# partition
echo  -e 'create cli transaction;
create auth partition '${partition}' { };
submit cli transaction' | tmsh -q
# asm policy
echo  -e 'create cli transaction;
cd /'${partition}';
load asm policy file '${asmFile}'
submit cli transaction' | tmsh -q
# traffic policy
echo  -e 'create cli transaction;
cd /'${partition}';
create ltm policy /'${partition}'/Drafts/app1_asm_policy_https controls add { asm } rules add { default { actions add { 1 { asm enable policy /Common/owasp-auto-tune} } ordinal 1 } } strategy /Common/first-match;
submit cli transaction' | tmsh -q

# publish traffic policy
echo  -e 'create cli transaction;
cd /'${partition}';
publish ltm policy /'${partition}'/Drafts/app1_asm_policy_https;
submit cli transaction' | tmsh -q

#service Discovery pool
echo  -e 'create cli transaction;
create sys application service /'${partition}'/'${appName}' template f5.service_discovery device-group same_az_failover_group traffic-group traffic-group-1 strict-updates disabled variables replace-all-with { basic__advanced { value no } basic__display_help { value hide } cloud__aws_bigip_in_ec2 { value yes } cloud__aws_region { value us-east-1 } cloud__aws_use_role { value no } cloud__cloud_provider { value aws } monitor__frequency { value 30 } monitor__http_method { value GET } monitor__http_version { value http11 } monitor__monitor { value "/#create_new#" } monitor__response { value 200 } monitor__type { value https } monitor__uri { value / } pool__interval { value 10 } pool__member_conn_limit { value 0 } pool__member_port { value 443 } pool__pool_to_use { value "/#create_new#" } pool__public_private { value private } pool__tag_key { value '${appTag}' } pool__tag_value { value '${appName}' } };
submit cli transaction' | tmsh -q


#virtual servers
echo  -e 'create cli transaction;
cd /'${partition}';
create ltm node /'${partition}'/'${node1}' { address '${node1}' };
create ltm virtual /'${partition}'/'${appName}'_http { description '${appName}'_http destination /'${partition}'/'${virtualAddress}':http ip-protocol tcp mask 255.255.255.255 persist none profiles replace-all-with { /Common/f5-tcp-progressive {} http } rules { /Common/_sys_https_redirect } source 0.0.0.0/0 source-address-translation { type automap } translate-address enabled translate-port enabled };
create ltm virtual /'${partition}'/'${appName}'_https {  description '${appName}'_https destination /'${partition}'/'${virtualAddress}':https ip-protocol tcp mask 255.255.255.255 persist replace-all-with { /Common/cookie { default yes } } pool /'${partition}'/'${appName}'.app/'${appName}'_pool security-log-profiles add { "Log all requests" } profiles replace-all-with { /Common/f5-tcp-progressive { } http websecurity } source 0.0.0.0/0 source-address-translation { type automap } translate-address enabled translate-port enabled };
submit cli transaction' | tmsh -q

# create BotDef and logging profile
echo  -e 'create cli transaction;
create security log profile /'${partition}'/'${appName}'_sec_log application replace-all-with { /'${partition}'/'${appName}' { filter replace-all-with { log-challenge-failure-requests { values replace-all-with { enabled } } request-type { values replace-all-with { all } } } response-logging illegal } } bot-defense replace-all-with { /'${partition}'/'${appName}' { filter { log-alarm enabled log-block enabled log-browser enabled log-browser-verification-action enabled log-captcha enabled log-challenge-failure-request enabled log-device-id-collection-request enabled log-honey-pot-page enabled log-malicious-bot enabled log-mobile-application enabled log-none enabled log-rate-limit enabled log-redirect-to-pool enabled log-suspicious-browser enabled log-tcp-reset enabled log-trusted-bot enabled log-unknown enabled log-untrusted-bot enabled } local-publisher /Common/local-db-publisher } };
create security bot-defense profile /'${partition}'/'${appName}'_bot { allow-browser-access enabled api-access-strict-mitigation enabled app-service none blocking-page {  type default } browser-mitigation-action block captcha-response { failure {  type default } first { type default } } cross-domain-requests allow-all description none deviceid-mode generate-after-access  dos-attack-strict-mitigation enabled enforcement-mode transparent enforcement-readiness-period 7 grace-period 300 honeypot-page {  type default } mobile-detection { allow-android-rooted-device disabled allow-any-android-package enabled allow-any-ios-package enabled allow-emulators disabled allow-jailbroken-devices disabled block-debugger-enabled-device enabled client-side-challenge-mode pass } perform-challenge-in-transparent disabled redirect-to-pool-name none signature-staging-upon-update disabled single-page-application disabled template relaxed whitelist replace-all-with { apple_touch_1 { match-order 2 url /apple-touch-icon*.png } favicon_1 { match-order 1 url /favicon.ico } } };
submit cli transaction' | tmsh -q

# add asm bot and logging
echo  -e 'create cli transaction;
modify ltm virtual /'${partition}'/'${appName}'_https profiles add { /'${partition}'/'${appName}'_bot } policies add { /'${partition}'/'${appName}'_asm_policy_https} security-log-profiles replace-all-with { /'${partition}'/'${appName}'_sec_log }
submit cli transaction' | tmsh -q

# save config
echo  -e 'create cli transaction;
save sys config partitions all;
submit cli transaction' | tmsh -q
