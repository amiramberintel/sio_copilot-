#!/usr/bin/tcsh -f


set fub = $1
set rule = $2

echo "${fub} ${rule}:" `zcat $FUB_PV_ARCHIVE/${fub}/duet/report/${fub}/${rule}.txt.gz | tail +15 | wc -l`

