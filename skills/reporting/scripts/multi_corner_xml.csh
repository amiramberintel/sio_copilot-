set par = $1
mkdir -p xml_comp/$par
foreach cor (func.max_low_cold.ttttcmaxtttt_m40.tttt func.max_turbo.ttttcmaxtttt_100.tttt func.max_fast.rcffcminpcff_125.prcs func.max_low.ttttcmaxtttt_100.tttt func.max_ulow.ttttcmaxtttt_100.tttt func.max_high.ttttcmaxtttt_100.tttt func.max_med.ttttcmaxtttt_100.tttt func.max_nom.ttttcmaxtttt_100.tttt)
set xml = $FCT_MODEL/latest_gfc0a_n2_${block}_bu_postcts/runs/$block/$tech/sta_pt/$cor/reports/${block}.${cor}_timing_summary_no_dfx.xml.filtered
cat $xml |grep "$par/" > xml_comp/$par/$par.$cor.xml
end
#/nfs/site/disks/ayarokh_wa/tools/reports/compare_xmls.py -xmls func.max_fast.rcffcminpcff_125.prcs:xml_comp/$par/${par}.func.max_fast.rcffcminpcff_125.prcs.xml func.max_high.ttttcmaxtttt_100.tttt:xml_comp/$par/${par}.func.max_high.ttttcmaxtttt_100.tttt.xml func.max_low.ttttcmaxtttt_100.tttt:xml_comp/$par/${par}.func.max_low.ttttcmaxtttt_100.tttt.xml func.max_low_cold.ttttcmaxtttt_m40.tttt:xml_comp/$par/${par}.func.max_low_cold.ttttcmaxtttt_m40.tttt.xml func.max_med.ttttcmaxtttt_100.tttt:xml_comp/$par/${par}.func.max_med.ttttcmaxtttt_100.tttt.xml func.max_turbo.ttttcmaxtttt_100.tttt:xml_comp/$par/${par}.func.max_turbo.ttttcmaxtttt_100.tttt.xml func.max_nom.ttttcmaxtttt_100.tttt:xml_comp/$par/${par}.func.max_nom.ttttcmaxtttt_100.tttt.xml func.max_ulow.ttttcmaxtttt_100.tttt:xml_comp/$par/${par}.func.max_ulow.ttttcmaxtttt_100.tttt.xml -csv xml_comp/$par/output_$par.csv -fields normalized_slack 


/nfs/site/disks/ayarokh_wa/tools/reports/compare_xmls.py -xmls max_fast:xml_comp/$par/${par}.func.max_fast.rcffcminpcff_125.prcs.xml max_high:xml_comp/$par/${par}.func.max_high.ttttcmaxtttt_100.tttt.xml max_low:xml_comp/$par/${par}.func.max_low.ttttcmaxtttt_100.tttt.xml max_low_cold:xml_comp/$par/${par}.func.max_low_cold.ttttcmaxtttt_m40.tttt.xml max_med:xml_comp/$par/${par}.func.max_med.ttttcmaxtttt_100.tttt.xml max_turbo:xml_comp/$par/${par}.func.max_turbo.ttttcmaxtttt_100.tttt.xml max_nom:xml_comp/$par/${par}.func.max_nom.ttttcmaxtttt_100.tttt.xml max_ulow:xml_comp/$par/${par}.func.max_ulow.ttttcmaxtttt_100.tttt.xml -csv xml_comp/$par/output_$par.csv -fields normalized_slack int_ext

