#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3


from collections import defaultdict
import json
import os
import pprint
import pwd
import sys
from threading import Lock
import time
import numpy as np
import pandas as pd
import logging
try:
    import modules.sio_mow_common as sio_mow_common
    from modules import sio_mow_db
except ImportError:
    import sio_mow_common
    import sio_mow_db


def logger_init():
    formatter = '%(levelname)s:[%(asctime)s - %(filename)s:%(lineno)s - %(funcName)30s() ] %(message)s'
    logging.basicConfig(format=formatter, level=logging.DEBUG)


logger = logging.getLogger(__name__)
logger.setLevel(logging.ERROR)


class ports_table:
    __df = None
    __output_file = None
    __pt_server = dict()
    __compress_by: str
    __sort_by: str
    __mow_data = dict(df=pd.DataFrame())
    __init_data: dict
    __sio_commnets = None
    __local_only_comments = False
    __lock = Lock()
    __port_to_all_related_ports = defaultdict(set)
    __comments_save_data = {'wns_new': 'slack', 'wns': 'slack'}
    __last_change = None
    __compressed_row = None
    __user_to_name: dict
    __compressed_df = None
    __port_to_updated_time: dict = dict()
    def __init__(self, fin_new, fin_old, comments, output_file, pt_server, init_data, local_only_comments=False) -> None:
        # logger.debug('Initializing ports_table')
        self.__compress_by = 'port'
        self.__sort_by = 'wns_new'
        
        self.__user_to_name = dict()
        self.__output_file = output_file
        self.__pt_server.update(pt_server)
        self.__init_data = init_data
        self.__local_only_comments = local_only_comments
        self.__sio_commnets = sio_mow_db.sio_commnets(
            self.__init_data['PRODUCT_NAME'], self.__compress_by)
        
        df = self.__init_dfs(fin_new=fin_new, fin_old=fin_old,
                             comments=comments, output_file=output_file)
        # logger.debug('Initializing __init_dfs')
        pt_ports, abutted_port = self.__get_ports_from_pt() # type: ignore
        # logger.debug('Initializing __get_ports_from_pt')

        if df is not None:
            pass
        elif pt_ports is not None:
            df = pt_ports
        else:
            logging.fatal("Cannot continue - problem with input data")
            raise Exception("Cannot continue")
        if 'comment' not in df:
            df['comment'] = ""
        if 'owner' not in df:
            df['owner'] = ""
        self.__make_df(df, pt_ports)
        # logger.debug('Initializing __make_df')
        self.__update_comments(True)
        # logger.debug('Initializing __update_comments')

        # logger.debug('Done')

    def __update_comments(self, force=False):
        ''' Return true if updated, e.g. last change date was changed '''
        if not self.__local_only_comments:
            last_change = self.__sio_commnets.last_change() # type: ignore
            if force or self.__last_change != last_change:
                self.__get_comments_from_db()
                self.__last_change = last_change
                return True
        if self.__last_change is None:
            self.__last_change = 0
        return False
    @property
    def get_latest_change(self):
        # logger.debug(f'Run')
        lch = self.__sio_commnets.last_change() # type: ignore
        if self.__last_change != lch:
            self.__last_change = lch
            changed_fields = self.__get_comments_from_db()
            # changed_fields = self.__mow_data['df']['port_compress'].to_list()
            # logger.debug(f'get_latest_change: {len(changed_fields)}')
            if changed_fields:
                df = self.__mow_data['df']
                mask = df[self.__compressed_row].isin(changed_fields) & (df['comment'].notna() | df['hsds'].notna())
                ret = df.loc[mask].to_dict(orient='records')
                # logger.debug(f'Return {len(ret)}')
                return ret
        # logger.debug(f'Done')
        return None
    @property
    def get_compress_by(self):
        return self.__compress_by

    @property
    def get_sort_by(self):
        return self.__sort_by

    @property
    def get_product_name(self):
        return self.__init_data['PRODUCT_NAME']

    @property
    def get_df(self):
        return self.__mow_data['df']

    @property
    def get_compressed_row(self):
        return self.__compressed_row

    def get_comments(self, port, get_last):
        return self.__sio_commnets.get_comments(port, get_last) # type: ignore

    def __get_ports_from_pt(self):
        errors, warnings, data = sio_mow_common.parse_data_from_server(
            sio_mow_common.get_data_from_pt_server(
                f'sio_mow_get_all_ports',
                self.__pt_server['address'],
                self.__pt_server['port']))
        if len(data['table']) > 0 and len(data['table'][0]) > 1:
            df = sio_mow_common.create_df_table_from_string(data['table'][0])
            df, abutted_port = sio_mow_common.compress_df_by(
                df, 'abutted_port')
            return df.rename(columns={'wns': 'wns_new'}), abutted_port
        return None
    
    def get_data_by_field(self, field):
        return self.__compressed_df.get_group(field).copy() # type: ignore
 
    def __make_df(self, df, port_df):
        # logger.debug('Start')
        self.__df, self.__compressed_row = sio_mow_common.compress_df_by(
            df, self.__compress_by)
        # logger.debug('compress_df_by')
        if port_df is not None:
            port_df, self.__compressed_row = sio_mow_common.compress_df_by(
                port_df, self.__compress_by)
        # logger.debug('compress_df_by')
        self.__compressed_df = df.groupby(self.__compressed_row)
        # logger.debug('groupby')

        self.__mow_data['df'] = df.loc[self.__compressed_df[self.__sort_by].idxmin()].sort_values(self.__sort_by)
        # logger.debug('loc')

        cols = list(self.__mow_data['df'])

        # cols.insert(0, cols.pop(cols.index(self.__compressed_row)))
        self.__mow_data['df'] = self.__mow_data['df'].loc[:, cols]
        if port_df is not None:
            ttt = port_df[[self.__compressed_row,
                           'abutted_port_compress']].drop_duplicates()
            tttt = ttt.copy()
            tttt.columns = ['abutted_port_compress', self.__compressed_row]
            tt = pd.concat([ttt, tttt],
                           ignore_index=True, sort=False)
        # logger.debug('concat')
        # tt.to_csv('/tmp_proj/ayarokh/t.csv', index = False)
            t = tt.dropna().groupby(self.__compressed_row)[
                'abutted_port_compress'].unique()
            self.__mow_data['df']['abutted_ports'] = self.__mow_data['df'][self.__compressed_row].apply(
                lambda port: ' '.join(map(str, t[port])) if port in t else "")
            self.__mow_data['df'] = self.__mow_data['df'].drop(
                columns=['abutted_port', 'abutted_port_compress'], errors='ignore')
        # logger.debug('apply + drop')

        if 'tns_new' in df.columns:
            d = df[[self.__compressed_row, 'tns_new']].groupby(
                [self.__compressed_row]).sum()
            self.__mow_data['df']['tns_new'] = self.__mow_data['df'][self.__compressed_row].apply(
                lambda port: d.loc[port]['tns_new'])

        # logger.debug('tns_new')
        if 'tns_prev' in df.columns:
            d = df[[self.__compressed_row, 'tns_prev']].groupby(
                [self.__compressed_row]).sum()
            self.__mow_data['df']['tns_prev'] = self.__mow_data['df'][self.__compressed_row].apply(
                lambda port: d.loc[port]['tns_prev'])

        self.__df.drop(columns=['abutted_port_compress',
                                self.__compressed_row], errors='ignore')
        if 'partitions' in df.columns:
            sep = ' '
            dd = df[[self.__compressed_row, 'partitions']].dropna(
                subset=['partitions']).groupby([self.__compressed_row])['partitions'].unique()

            def splandt2(port, dddd):
                ret = set()
                if port in dddd.index:
                    d = dddd.loc[port]
                    for dd in d:
                        if dd != "":
                            for ddd in dd.split(sep):
                                ret.add(ddd.strip())
                return sep.join(ret)

            self.__mow_data['df']['partitions'] = self.__mow_data['df'][self.__compressed_row].apply(
                splandt2, dddd=dd)
        # logger.debug('partitions')
        if 'ports' in df.columns:
            sep = '|'

            self.__mow_data['df']['ports'] = self.__mow_data['df']['ports'].apply(
                lambda lst: [sio_mow_common.compress_pin(item) for item in lst.split(sep)])
            self.__mow_data['df'] = df.explode('ports')

            self.__mow_data['df']['ports'] = self.__mow_data['df'].groupby(
                self.__compressed_row)['ports'].transform(lambda x: ' | '.join(sorted(x.unique())))
            self.__mow_data['df'] = df.drop_duplicates(
                subset=[self.__compressed_row])
        for _, row in self.__mow_data['df'].iterrows():
            n = row[self.__compressed_row]
            self.__port_to_all_related_ports[n].add(n)
            to_iterate = set()
            if 'abutted_ports' in row:
                to_iterate.update(x for x in [s.strip() for word in row['abutted_ports'].split(
                    "|") for s in word.split() if s and s.strip()] if x)
            if 'ports' in df.columns:
                to_iterate.update(x for x in [s.strip() for word in row['ports'].split(
                    "|") for s in word.split() if s and s.strip()] if x)
            self.__port_to_all_related_ports[n].update(to_iterate)
            for sp in to_iterate:
                self.__port_to_all_related_ports[sp].add(n)
        # logger.debug('iterrows')
        # logger.debug('ports')
        self.__mow_data['df'].insert(
            0, self.__compressed_row, self.__mow_data['df'].pop(self.__compressed_row))
        self.__mow_data['df'].reset_index(inplace=True, drop=True)
        # self.bulk_check_and_insert_to_db()

    def getpwuid(self, user):
        if user not in self.__user_to_name:
            try:
                self.__user_to_name[user] = pwd.getpwuid(user).pw_name
            except KeyError:
                self.__user_to_name[user] = user
        return self.__user_to_name[user]


    def __make_port_to_port(self, ports2):
        '''
            ports1 from DF
            ports2 from DB
        '''
        p2p = defaultdict(list)
        # p2p = dict()
        d = sio_mow_db.fields_cross_reference_db()
        for p in ports2:
            for pp in d[p]:
                p2p[pp].append(p)
        # for p1 in ports1:
        #     if p1 in p2p:
        #         ret[p1].append(p2p[p1])
        #     else:
        #         ret[p1].append(p1)
        return p2p

    def __get_comments_from_db(self):
        start_time = time.time()
        hsd = sio_mow_db.hsdes()
        logger.debug(f'hsdes: {abs(start_time - (start_time := time.time()))}')

        data_per_port_hsds = hsd.get_all_hsdes(self.__init_data['PRODUCT_NAME'])
        logger.debug(f'get_all_hsdes: {abs(start_time - (start_time := time.time()))}')
        # logger.warning('USED test DB')
        # data_per_port_hsds = hsd.get_all_hsdes('test')

        df = self.__mow_data['df']
        data_per_port_comments = self.__sio_commnets.get_all_comments_last() # type: ignore
        logger.debug(f':get_all_comments_last {abs(start_time - (start_time := time.time()))}')

        port_to_port = self.__make_port_to_port(set(set(data_per_port_comments.keys()) | set(data_per_port_hsds.keys())))
        logger.debug(f'__make_port_to_port: {abs(start_time - (start_time := time.time()))}')

        def ggg(row):
            wns_comment = None
            abutted_comment = None
            ports = set()
            ports.add(row[self.__compressed_row])
            ports.update(self.__port_to_all_related_ports[row[self.__compressed_row]])

            abutted_comments = []
            category = None
            hsds = list()
            for port in ports:
                category = None
                if port in port_to_port:
                    for p2p in port_to_port[port]:
                        if p2p in data_per_port_comments:
                            dd = data_per_port_comments[p2p].get('date', None)
                            user = data_per_port_comments[p2p].get('by', None)
                            slack = data_per_port_comments[p2p].get('slack', None)
                            comment = data_per_port_comments[p2p].get('comment', '')
                            owner = data_per_port_comments[p2p].get('owner', '')
                            category = data_per_port_comments[p2p].get('category', '')
                            if comment is not None and comment != "":
                                abutted_comments.append(dict(port=port, comment=comment, by=user, at=dd, slack=slack, owner=owner))
            if len(abutted_comments) > 0:
                abutted_comments.sort(key=lambda k: k['at'], reverse=True)
                for auc in abutted_comments:
                    auc.update((k, v.strftime("%Y-%m-%d")) for k, v in auc.items() if v is not None and k == 'at')
                abutted_comment = json.dumps(abutted_comments)
            port = row[self.__compressed_row]
            hsds = set()
            if port in data_per_port_hsds:
                for p2p in port_to_port[port]:
                    hsds |= {d['hsd_id'] for d in data_per_port_hsds.get(p2p, [])}

            if port in port_to_port:
                for p2p in port_to_port[port]:
                    if p2p in data_per_port_comments:
                        category = data_per_port_comments[p2p].get('category', '')
                        wns_comment = data_per_port_comments[p2p].get('slack', None)

                        com = data_per_port_comments[p2p].get('comment', None)
                        if com is not None and com != "":
                            d = data_per_port_comments[p2p].get('date', None)
                            dd = d.strftime("%Y-%m-%d") if d is not None else None
                            us = data_per_port_comments[p2p].get('by', '')
                            return com, us, dd, data_per_port_comments[p2p].get('owner', None), abutted_comment, category, wns_comment, " ".join([str(x) for x in hsds]), d
            return "", "", None, None, abutted_comment, category, wns_comment, " ".join([str(x) for x in hsds]), None
        df[['comment', 'by', 'date', 'owner', 'all_comments', 'category', 'wns_comment', 'hsds', 'orig_date']] = df.apply(ggg, axis=1, result_type="expand")
        diff_keys = []
        tmp = dict(zip(df[self.__compressed_row], df['orig_date']))
        ptupt = self.__port_to_updated_time
        if self.__port_to_updated_time:
            diff_keys = [k for k in tmp if not(pd.isnull(tmp[k]) and pd.isnull(ptupt[k])) and tmp[k] != ptupt[k]]
        self.__port_to_updated_time = tmp
        logger.debug(f'__port_to_updated_time: {abs(start_time - (start_time := time.time()))}')
        df.drop(columns=['orig_date'], inplace=True, errors='ignore')
        logger.debug(f'apply: {abs(start_time - (start_time := time.time()))}')
        if 'wns_new' in df:
            cc = df.columns.get_loc('wns_new')
            for c in reversed(['comment', 'by', 'date']):
                df.insert(cc+1, c, df.pop(c)) # type: ignore
            # df['wns-wns_comment'] = df['wns_new']-df['wns_comment']
            df.loc[:, 'wns-wns_comment'] = df['wns_new'] - df['wns_comment']
        logger.debug(f'rest: {abs(start_time - (start_time := time.time()))}')
        logger.debug(f'{diff_keys=}')
        return diff_keys

    def __init_dfs(self, fin_new, fin_old, comments, output_file):
        '''
            init first df
            return None if no inputs files given
            otherwise return dataframe
        '''
        df = None
        if fin_new:
            df, d = sio_mow_common.compress_df_by(
                sio_mow_common.mow_read_port_sum_report(fin_new), self.get_compress_by)
            if fin_old:
                df_old, d = sio_mow_common.compress_df_by(
                    sio_mow_common.mow_read_port_sum_report(fin_old), self.get_compress_by)
                df_old.drop(columns=['ports', 'partitions', 'exceptions',
                            'number_of_paths'], inplace=True, errors='ignore')
                df = pd.merge(df, df_old, how='outer', on=self.get_compress_by,
                              suffixes=('_new', '_prev'))
                df.drop(columns=[f'{self.get_compress_by}_compress_prev'],
                        inplace=True, errors='ignore')
                df.drop(columns=['direction_prev'],
                        inplace=True, errors='ignore')
                # df['port_new'] = df['port_new'].fillna(df['port_prev'])
                if 'ports' in df:
                    df.ports = df.ports.fillna('')
            if 'port_compress_new' in df.columns:
                df = df.rename(columns={'port_compress_new': 'port_compress'})
            df = df.rename(columns={'port': 'port_new', 'wns': 'wns_new',
                                    'norm_wns': 'norm_wns_new', 'tns': 'tns_new'}, )
            if comments:
                df_comments, d = sio_mow_common.compress_df_by(
                    sio_mow_common.mow_read_compare_models_report(comments)[[self.get_compress_by, 'comment']], self.get_compress_by)
                df = pd.merge(df, df_comments, how='left',
                              on='port_compress', suffixes=('_new', '_prev'))
            else:
                if os.path.isfile(output_file):
                    df_comments = pd.read_csv(output_file)[
                        ['port_compress', 'comment']]
                    df_comments = df_comments[df_comments['port_compress'] != '']
                    df = pd.merge(df, df_comments, how='outer', left_on='port_compress',
                                  right_on='port_compress', suffixes=('_new', '_prev'))
            df = df.rename(columns={'port_new': 'port'}
                           ).sort_values(self.__sort_by)
            df = df[df[self.get_compress_by] != ""]
            df.fillna({self.__sort_by: 0}, inplace=True)
            df.replace({self.get_compress_by: ''}, np.nan, inplace=True)
            df.dropna(subset=[self.get_compress_by], inplace=True)
        return df

    def __update_and_save(self, port, data, func):
        with self.__lock:
            row = self.__mow_data['df'][self.__mow_data['df']
                                        [self.__compressed_row] == port]
            if not self.__local_only_comments:
                for c, t in self.__comments_save_data.items():
                    if c in row:
                        for _, r in row.iterrows():
                            data[t] = r[c]
                func(port, data)
            else:
                for k, v in data.items():
                    if k in self.__mow_data['df']:

                        self.__mow_data['df'].loc[row.index, k] = v
                print('Save to central DB is disabled')
            self.__update_comments()
            if self.__output_file:
                columns_to_save = self.__mow_data['df'].columns
                self.__mow_data['df'].loc[:, ~columns_to_save.isin(
                    ['link'])].to_csv(self.__output_file, index=False)

    def set_category(self, port, data):
        self.__update_and_save(
            port, data, self.__sio_commnets.add_category)  # type: ignore


def debug():
    port = 'icore0/par_msid/rortifuuopv_m905h'
    p = '/nfs/site/disks/pnc_fct_bu_3/work_area/RTLB0_25ww25a_client_ww25_5-FCT25WW28G_dcm_daily_b0-CLK022.bu_postcts/runs/core_client/1278.6/sta_pt/func.max_med.ttttcmaxtttt_100.tttt/logs/sio_mow_port_tns.csv'
    # fin_old = '/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/GFC/links/latest_gfc0a_n2_core_server_bu_postcts/runs/core_server/n2p_htall_conf4/sta_pt/spec.max_high.T_85.typical/logs/sio_mow_port_tns.csv'
    pt = ports_table([p], [p], None, '/tmp/ayarokh/test.comments', dict(
        address='sccc14704908', port=9901), dict(PRODUCT_NAME='PNC78CLIENT'), False)
    l = pt.get_latest_change
    return 0


def main():
    logger_init()
    return debug()
    return 0


if __name__ == '__main__':
    # logger_init()
    sys.exit(main())
