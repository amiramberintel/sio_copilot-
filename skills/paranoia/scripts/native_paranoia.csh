echo "ep,PT,XML" > native_paranoia/test.csv
foreach ep (`cat native_paranoia/xml_end_slack.csv native_paranoia/native_end_slack.csv | awkc '{print $1}' | sort -u`)
set tst = `grep -w "$ep" native_paranoia/native_end_slack.csv | awkc '{print $2}'`
set ref = `grep -w "$ep" native_paranoia/xml_end_slack.csv | awkc '{print $2}'`
echo "$ep,$tst,$ref" >> native_paranoia/test.csv
end
