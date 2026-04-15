#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

from collections import Counter, defaultdict
import os
import pprint
import subprocess
import sys
import time
import pandas as pd
import tabulate
import pymongo
import logging
import datetime
import argparse
import pwd
import grp
# import modules.params as params
# import params

try:
    import modules.params as params
except ImportError:
    import params
logger = logging.getLogger(__name__)


def remove_consecutive_slashes(s):
    s = remove_icore_prefix(s)
    return '/'.join(filter(None, s.split('/')))


def remove_icore_prefix(port: str):
    if port:
        port = port.removeprefix('icore0/').removeprefix('icore1/')
    return port


__user_to_name = dict()


def getpwuid(user):
    if user not in __user_to_name:
        try:
            __user_to_name[user] = pwd.getpwuid(user).pw_name
        except KeyError:
            __user_to_name[user] = user
    return __user_to_name[user]


class fields_cross_reference_db:
    '''
    works only with data where partition start with par_... '''
    __field_to_field = defaultdict(list)

    def add(self, field):
        if field not in self.__field_to_field:
            if not field.startswith('par_'):
                subfields = []
                self.__field_to_field[field]
                for i in range(1, len(field)):
                    if field[i] == '/':
                        f = field[i+1::]
                        self.__field_to_field[f]
                        self.__field_to_field[field].append(i+1)
                        for sf in subfields:
                            self.__field_to_field[sf].append(
                                i+1 - (len(field)-len(sf)))
                        subfields.append(f)

                        if f.startswith('par_'):
                            break
        return self.__field_to_field[field]

    def __getitem__(self, field):
        field = remove_consecutive_slashes(field)
        ret = {field}
        for i in self.add(field):
            ret.add(field[i::])
        [ret.add(s) for s in self.__field_to_field.keys()
         if s.endswith(f"/{field}")]
        return list(ret)


class permissions:
    users_collection = 'users'
    view_permissions_collection = 'view_permission'
    write_roles = ['admin', 'contributer', 'temporary']

    def user_has_view_permissions(self, username, product_name):
        sdb = sio_db(product_name)
        if sdb.ro[self.view_permissions_collection].count_documents({}) > 0:
            user_uid = pwd.getpwnam(username).pw_uid
            if user_uid > 0:
                user_data = pwd.getpwuid(user_uid)
                user_groups = [grp.getgrgid(g).gr_name for g in os.getgrouplist(
                    user_data.pw_name, user_data.pw_gid)]
                read_groups = sdb.ro[self.view_permissions_collection].find({"read": True}, {
                                                                            "group": 1})
                for p in read_groups:
                    if p.get('group') in user_groups:
                        return True
                return False
        else:
            return True

    def user_can_comment(self, user_uid, product_name):
        if user_uid > 0:
            sdb = sio_db(product_name)
            p = sdb.ro[self.users_collection].find_one({'wwid': user_uid})

            if p and p.get('role', None) in self.write_roles:
                return True
        return False

    def user_get_role(self, product_name, user_wwid):
        sdb = sio_db(product_name)
        p = sdb.ro[self.users_collection].find_one(
            {'wwid': user_wwid}, {'role': 1})
        if p:
            return p.get('role', None)
        return None

    def get_admins(self, product_name):
        sdb = sio_db(product_name)
        p = sdb.ro[self.users_collection].find(
            {'role': self.write_roles[0]}, {'_id': 0, 'wwid': 1})
        return [pp['wwid'] for pp in p] if p else []

    def user_is_admin(self, product_name,  user_wwid):
        if user_wwid > 0:
            sdb = sio_db(product_name)
            p = sdb.ro[self.users_collection].find_one({'wwid': user_wwid})

            if p and p.get('role', None) == self.write_roles[0]:
                return True
        return False

    def user_add_request(self, product_name, user_wwid, message):
        if self.user_can_comment(user_wwid, product_name):
            return None, "User already can comment"
        sdb = sio_db(product_name)
        ret = sdb.rw[self.users_collection].update_one(
            {'wwid': user_wwid},
            {'$set': {'request': message}}, upsert=True)
        return ret, ""

    def user_get_request(self, product_name, user_wwid):
        sdb = sio_db(product_name)
        p = sdb.ro[self.users_collection].find_one({'wwid': user_wwid})
        if p:
            req = p.get('request', None)
            is_write = False if p.get('role', None) is None else p.get(
                'role') in self.write_roles
            return is_write, req
        return False, None

    def user_set_permission(self, product_name, user_wwid, user_admin_wwid, permission, force=False):
        if not force and not self.user_is_admin(product_name, user_admin_wwid):
            return None, 'You are not an admin'
        if permission not in self.write_roles:
            return None, f'Unknow role, should be one of: {",".join(self.write_roles)}'
        sdb = sio_db(product_name)
        ret = sdb.rw[self.users_collection].update_one(
            {'wwid': user_wwid},
            {'$set': {'by': user_admin_wwid, 'role': permission}}, upsert=True)
        return ret, 'Done'


class sio_db:
    db_name = 'aladdin'
    db_connection = {'rw': None, 'ro': None}
    product_name = None
    connect_string = params.connect_string

    def __init__(self, product_name=None) -> None:
        if product_name:
            self.product_name = product_name
        else:
            self.product_name = os.getenv('PRODUCT_NAME')

    def connect_to_db(self, type='ro'):
        db = None
        if self.db_connection[type] is None:
            client = pymongo.MongoClient(
                self.connect_string[type], tls=True, tlsAllowInvalidCertificates=True)
            db = client[self.db_name]
            self.db_connection[type] = db # type: ignore
        else:
            db = self.db_connection[type]
        return db[self.product_name] # type: ignore

    def get_latest_by_tag(self, tag):
        ret = None
        try:
            ret = self.ro['sessions'].find({'tag': tag}).sort(
                [('date', pymongo.DESCENDING)])[0]['address']
        except:
            pass
        return ret

    @property
    def ro(self):
        return self.connect_to_db('ro')

    @property
    def rw(self):
        return self.connect_to_db('rw')

    @staticmethod
    def get_collection_names(names={}):
        client = pymongo.MongoClient(
            __class__.connect_string['ro'], tls=True, tlsAllowInvalidCertificates=True)
        db = client[__class__.db_name]
        a = db.list_collection_names(filter={'name': names})
        return list(a)


class hsdes:
    __all_hsdes = 'hsdes_all'
    __fields_cross_reference_db = fields_cross_reference_db()

    @staticmethod
    def get_gui_from_db(project) -> list[dict]:
        ret = []
        if project == "PNC78CLIENT":

            ret.append({"id": "rtl4be",
                        "name": "rtl4be",
                        "hsd": {"tenant": "ip_cpu_bigcore", "subject": "bugeco"},
                        "gui": {"title": "Select and fill", "elements": [
                            {"id": "title", "type": "text", "required": True,
                                "placeholder": "Title", "value": "[RTL4BE]"},
                            {"id": 'bugeco.env_found', "type": "text",
                                "value": "logic_verif.Code_review", "required": True},
                            {"id": 'bugeco.failure_signature', "type": "text",
                                "value": "N/A", "required": True},
                            {"id": 'family', "type": "text",
                                "value": "PantherCove (PNC)", "required": True},
                            {"id": 'release', "type": "text",
                                "required": True, "value": "pnc-b0"},
                            {"id": 'component', "type": "text", "required": True, "choises": [
                                'pnc.ip.dft', 'pnc.ip.exe', 'pnc.ip.fe', 'pnc.ip.meu', 'pnc.ip.mlc', 'pnc.ip.msid', 'pnc.ip.ooo', 'pnc.ip.ooo.alloc', 'pnc.ip.ooo.rob', 'pnc.ip.ooo.rs', 'pnc.ip.pm']},
                            {"id": 'bugeco.is_security', "type": "text",
                                "value": "no", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.legacy_bug',
                                "type": "text", "value": "no", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.path_to_failure',
                                "type": "text", "value": "N/A", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.performance_impact',
                                "type": "text", "value": "no", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.power_impact',
                                "type": "text", "value": "N/A", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.project_specific_change',
                                "type": "text", "required": True, "value": "yes"},
                            {"id": 'ip_cpu_bigcore.bugeco.related_feature', "type": "text", "required": True,
                                "value": "ip_cpu_bigcore.feature.feature_name=BE work::::family=LionCove (LNC) Family::::id=1308106179"},
                            {"id": 'bugeco.root_cause', "type": "text",
                                "required": True, "value": "RTL4BE"},
                            {"id": 'bugeco.test_found', "type": "text",
                                "required": True, "value": "n/a"},
                            {"id": 'bugeco.type', "type": "text",
                                "required": True, "value": "enhancement"},
                            {"id": 'bugeco.team_found', "type": "text",
                                "required": True, "value": ""},
                            {"id": 'ip_cpu_bigcore.bugeco.validator',
                                "type": "text", "required": True, "value": ""},
                            {"id": "priority", "type": "radio", "choises": [
                                "4-low", "3-medium", "2-high",  "1-showstopper"]},
                            {"id": "description", "type": "textarea",
                                "required": True, "placeholder": "Description"},
                        ]}
                        })
            ret.append(
                {"id": "sio2po",
                 "name": "sio2po",
                 "hsd": {"tenant": "ip_cpu_bigcore", "subject": "ar"},
                 "gui": {"title": "Select and fill", "elements": [
                        {"id": "title", "type": "text",
                            "required": True, "placeholder": "Title", "value": "[SIO2PO]", },
                        {"id": "owner", "type": "text",
                            "required": True, "placeholder": "Owner"},
                        {"id": "notify", "type": "text", "required": False, "placeholder": "Enter to notificate"},
                        {"id": "send_mail", "type": "radio",
                            "choises": [True, False]},
                        {"id": "tag", "type": "text", "placeholder": "Start typing...", "required": True, "choises":
                         ["pncb0_sio2po_core_client", "pncb0_sio2po_icore", "pncb0_sio2po_par_exe", "pncb0_sio2po_par_fe", "pncb0_sio2po_par_fmav0", "pncb0_sio2po_par_fmav1",
                                                                                                    "pncb0_sio2po_par_meu", "pncb0_sio2po_par_mlc", "pncb0_sio2po_par_msid", "pncb0_sio2po_par_ooo_int", "pncb0_sio2po_par_ooo_vec", "pncb0_sio2po_par_pm", "pncb0_sio2po_par_pmh", "pncb0_sio2po_par_tmul_stub"]},
                        {"id": "priority", "type": "radio", "choises": [
                            "4-low", "3-medium", "2-high",  "1-showstopper"]},
                        {"id": "description", "type": "textarea", "required": True, "placeholder": "Description"}]}}
            )
            ret.append({"id": "rtl4be_old",
                        "name": "rtl4be (TESTS ONLY)",
                        "hsd": {"tenant": "ip_cpu_bigcore", "subject": "ar"},
                        "gui": {"title": "Select and fill", "elements": [
                            {"id": "title", "type": "text",
                             "required": True, "placeholder": "Title", "value": "[RTL4BE]"},
                            {"id": "owner", "type": "text",
                             "required": True, "placeholder": "Owner"},
                            {"id": "send_mail", "type": "radio",
                             "choises": [True, False]},
                            {"id": "notify", "type": "text", "required": False, "placeholder": "Enter to notificate"},
                            {"id": "tag", "type": "text", "placeholder": "Start typing...", "required": True, "choises":
                             ["pnc_rtl4be_core_client", "pnc_rtl4be_icore", "pnc_rtl4be_par_exe", "pnc_rtl4be_par_fe", "pnc_rtl4be_par_fmav0", "pnc_rtl4be_par_fmav1",
                              "pnc_rtl4be_par_meu", "pnc_rtl4be_par_mlc", "pnc_rtl4be_par_msid", "pnc_rtl4be_par_ooo_int", "pnc_rtl4be_par_ooo_vec", "pnc_rtl4be_par_pm", "pnc_rtl4be_par_pmh", "pnc_rtl4be_par_tmul_stub"]},
                            {"id": "priority", "type": "radio", "choises": [
                                "4-low", "3-medium", "2-high",  "1-showstopper"]},
                            {"id": "description", "type": "textarea", "required": True, "placeholder": "Description"}]
                        }})
        elif project == "GFCN2CLIENT" or project == "GFCN2SERVER":
            a = 'server'
            if project == "GFCN2CLIENT":
                a = 'client'
            ret.append({"id": "rtl4be",
                        "name": "rtl4be",
                        "hsd": {"tenant": "ip_cpu_bigcore", "subject": "bugeco"},
                        "gui": {"title": "Select and fill", "elements": [
                            {"id": "title", "type": "text", "required": True,
                                "placeholder": "Title", "value": "[RTL4BE]"},
                            {"id": 'bugeco.env_found', "type": "text",
                                "value": "logic_verif.Code_review", "required": True},
                            {"id": 'bugeco.failure_signature', "type": "text",
                                "value": "N/A", "required": True},
                            {"id": 'family', "type": "text",
                                "value": "GriffinCove (GFC)", "required": True},
                            {"id": 'bugeco.is_security', "type": "text",
                                "value": "no", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.legacy_bug',
                                "type": "text", "value": "no", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.path_to_failure',
                                "type": "text", "value": "N/A", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.performance_impact',
                                "type": "text", "value": "no", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.power_impact',
                                "type": "text", "value": "N/A", "required": True},
                            {"id": 'ip_cpu_bigcore.bugeco.project_specific_change',
                                "type": "text", "required": True, "value": "yes"},
                            {"id": 'ip_cpu_bigcore.bugeco.related_feature', "type": "text", "required": True,
                                "value": "ip_cpu_bigcore.feature.feature_name=RTL4BE::::family=GriffinCove (GFC)::::id=13012653628"},
                            {"id": 'release', "type": "text",
                                "required": True, "value": "gfc-a0"},
                            {"id": 'bugeco.root_cause', "type": "text",
                                "required": True, "value": "RTL4BE"},
                            {"id": 'bugeco.test_found', "type": "text",
                                "required": True, "value": "n/a"},
                            {"id": 'bugeco.type', "type": "text",
                                "required": True, "value": "enhancement"},
                            {"id": 'component', "type": "text", "required": True, "choises": [
                                'gfc.ip.dft', 'gfc.ip.exe', 'gfc.ip.fe', 'gfc.ip.meu', 'gfc.ip.mlc', 'gfc.ip.msid', 'gfc.ip.ooo', 'gfc.ip.ooo.alloc', 'gfc.ip.ooo.rob', 'gfc.ip.ooo.rs', 'gfc.ip.pm']},
                            {"id": "notify", "type": "text", "required": False, "placeholder": "Enter to notificate"},
                            {"id": 'ip_cpu_bigcore.bugeco.validator',
                                "type": "text", "required": True, "value": ""},
                            {"id": "priority", "type": "radio", "choises": [
                                "4-low", "3-medium", "2-high",  "1-showstopper"]},
                            {"id": "description", "type": "textarea",
                                "required": True, "placeholder": "Description"}
                        ]}
                        })
            ret.append(
                {"id": "sio2po",
                 "name": "sio2po",
                 "hsd": {"tenant": "ip_cpu_bigcore", "subject": "ar"},
                 "gui": {"title": "Select and fill", "elements": [
                        {"id": "title", "type": "text",
                            "required": True, "placeholder": "Title", "value": "[SIO2PO]", },
                        {"id": "owner", "type": "text",
                            "required": True, "placeholder": "Owner"},
                        {"id": "notify", "type": "text", "required": False, "placeholder": "Enter to notificate"},
                        {"id": "send_mail", "type": "radio",
                            "choises": [True, False]},
                        {"id": "tag", "type": "text", "placeholder": "Start typing...", "required": True, "choises":
                         [f"gfca0_sio2po_core_{a}", "gfca0_sio2po_icore", "gfca0_sio2po_par_exe", "gfca0_sio2po_par_fe", "gfca0_sio2po_par_fmav0", "gfca0_sio2po_par_fmav1",
                                                                                                    "gfca0_sio2po_par_meu", "gfca0_sio2po_par_mlc", "gfca0_sio2po_par_msid", "gfca0_sio2po_par_ooo_int", "gfca0_sio2po_par_ooo_vec", "gfca0_sio2po_par_pm", "gfca0_sio2po_par_pmh", "gfca0_sio2po_par_tmul_stub"]},
                        {"id": "priority", "type": "radio", "choises": [
                            "3-medium", "2-high", "4-low", "1-showstopper"]},
                        {"id": "description", "type": "textarea", "required": True, "placeholder": "Description"}]}},
            )
            ret.append(
                {"id": "tip2sio",
                 "name": "tip2sio",
                 "hsd": {"tenant": "ip_cpu_bigcore", "subject": "ar"},
                 "gui": {"title": "Select and fill", "elements": [
                        {"id": "title", "type": "text",
                            "required": True, "placeholder": "Title", "value": "[TIP2SO]", },
                        {"id": "owner", "type": "text",
                            "required": True, "placeholder": "Owner"},
                        {"id": "notify", "type": "text", "required": False, "placeholder": "Enter to notificate"},
                        {"id": "send_mail", "type": "radio",
                            "choises": [True, False]},
                        {"id": "tag", "type": "text", "placeholder": "Start typing...", "required": True, "choises":
                         [f"gfca0_tip2so_core_{a}", "gfca0_tip2so_icore", "gfca0_tip2so_par_exe", "gfca0_tip2so_par_fe", "gfca0_tip2so_par_fmav0", "gfca0_tip2so_par_fmav1",
                                                                                                    "gfca0_tip2so_par_meu", "gfca0_tip2so_par_mlc", "gfca0_tip2so_par_msid", "gfca0_tip2so_par_ooo_int", "gfca0_tip2so_par_ooo_vec", "gfca0_tip2so_par_pm", "gfca0_tip2so_par_pmh", "gfca0_tip2so_par_tmul_stub"]},
                        {"id": "priority", "type": "radio", "choises": [
                            "3-medium", "2-high", "4-low", "1-showstopper"]},
                        {"id": "description", "type": "textarea", "required": True, "placeholder": "Description"}]}},
            )
            ret.append({"id": "rtl4be_old",
                        "name": "rtl4be (TESTS ONLY)",
                        "hsd": {"tenant": "ip_cpu_bigcore", "subject": "ar"},
                        "gui": {"title": "Select and fill", "elements": [
                            {"id": "title", "type": "text",
                             "required": True, "placeholder": "Title", "value": "[RTL4BE]", },
                            {"id": "owner", "type": "text",
                             "required": True, "placeholder": "Owner"},
                            {"id": "notify", "type": "text", "required": False, "placeholder": "Enter to notificate"},
                            {"id": "send_mail", "type": "radio",
                                "choises": [True, False]},
                            {"id": "tag", "type": "text", "placeholder": "Start typing...", "required": True, "choises":
                             [f"gfc_rtl4be_core_{a}", "gfc_rtl4be_icore", "gfc_rtl4be_par_exe", "gfc_rtl4be_par_fe", "gfc_rtl4be_par_fmav0", "gfc_rtl4be_par_fmav1",
                              "gfc_rtl4be_par_meu", "gfc_rtl4be_par_mlc", "gfc_rtl4be_par_msid", "gfc_rtl4be_par_ooo_int", "gfc_rtl4be_par_ooo_vec", "gfc_rtl4be_par_pm", "gfc_rtl4be_par_pmh", "gfc_rtl4be_par_tmul_stub"]},
                            {"id": "priority", "type": "radio", "choises": [
                                "3-medium", "2-high", "4-low", "1-showstopper"]},
                            {"id": "description", "type": "textarea", "required": True, "placeholder": "Description"}]}})
        return ret

    def save_hsdes_id_to_db(self, product_name, data_to_save: dict, port: str | list | None = None):
        sdb = sio_db(product_name=product_name)
        if 'data' not in data_to_save:
            data_to_save |= {
                'date': datetime.datetime.now(datetime.timezone.utc)}
        sdb.rw[__class__.__all_hsdes].insert_one(data_to_save)
        if port:
            data = {__class__.__all_hsdes: data_to_save}
            comments_collection = sio_commnets.get_comments_collection_name()
            if isinstance(port, list):
                for p in port:
                    ret = sdb.rw[comments_collection].find_one_and_update(
                        {'port': p}, {'$push': data}, upsert=True)
                    print(ret)
            else:
                ret = sdb.rw[comments_collection].find_one_and_update(
                    {'port': port}, {'$push': data}, upsert=True)

    def get_all_hsdes(self, product_name):
        comments_collection = sio_commnets.get_comments_collection_name()
        sdb = sio_db(product_name=product_name)
        cursor = sdb.ro[comments_collection].find({"hsdes_all": {"$exists": True}}, {
                                                  "port": 1, "hsdes_all": 1, "_id": 0})
        result_dict = {
            doc["port"]: [{"hsd_id": hsd["hsd_id"], "date": hsd["date"].date()}
                          for hsd in doc["hsdes_all"]]
            for doc in cursor
        }
        return result_dict

    def get_hsd_for_name(self, product_name, field):

        def get_comments(self):
            raise NotImplementedError

        fields = self.__fields_cross_reference_db[field]
        fields.append(field)
        comments_collection = sio_commnets.get_comments_collection_name()
        sdb = sio_db(product_name=product_name)
        cursor = sdb.ro[comments_collection].find(
            {"port": {"$in": fields}, "hsdes_all": {"$exists": True}},
            {"port": 1, "hsdes_all": 1, "_id": 0}
        )

        # Convert results to dictionary
        result_dict = {
            field: [{"hsd_id": hsd["hsd_id"], "date": hsd["date"].date()}
                    for doc in cursor for hsd in doc["hsdes_all"]]
        }
        return result_dict

    def get_hsd_for_names(self, product_name, fields):
        to_check = set()
        for field in fields:
            to_check.update(self.__fields_cross_reference_db[field])
        to_check.update(fields)
        comments_collection = sio_commnets.get_comments_collection_name()
        sdb = sio_db(product_name=product_name)
        cursor = sdb.ro[comments_collection].find(
            {"port": {"$in": list(to_check)}, "hsdes_all": {"$exists": True}},
            {"port": 1, "hsdes_all": 1, "_id": 0}
        )

        # Convert results to dictionary
        result_dict = {
            'field': [{"hsd_id": hsd["hsd_id"], "date": hsd["date"].date()} for doc in cursor for hsd in doc["hsdes_all"]]
        }
        return result_dict


class sio_commnets:
    __sio_db = None
    __field: str
    __comments_collection = 'ports_comments'
    __fields_cross_reference_db = fields_cross_reference_db()

    def __init__(self, product_name: str, field: str) -> None:
        self.__sio_db = sio_db(product_name)
        self.__field = field
        self.__make_cross_reference_db()

    def crd_get_latest_comments(self, field):
        start = time.perf_counter()
        fields = self.__fields_cross_reference_db[field]
        end = time.perf_counter()
        pipeline = [
            {"$match": {self.__field: {"$in": fields}}},  # Find matching fields
            {"$unwind": "$data"},  # Flatten the "data" array into separate records
            {  # Add data while keeping all fields from "data"
                "$addFields": {
                    f"data.{self.__field}": f"${self.__field}"
                }
            },
            {  # Reshape the document to only keep "data" fields
                "$replaceRoot": {
                    "newRoot": "$data"
                }
            },
            {"$sort": {"date": -1}}  # Sort by date (ascending)
        ]
        # Run aggregation
        result = self.__sio_db.ro[self.__comments_collection].aggregate( # type: ignore
            pipeline)
        # logger.debug(result)
        r = []
        for v in list(result):
            d = dict()
            for kk, vv in v.items():
                if kk == 'date':
                    vv = vv.date()
                elif kk == 'by':
                    vv = getpwuid(vv)
                d[kk] = vv
            r.append(d)
        return r

    def __make_cross_reference_db(self):
        ports = self.get_all_fields()
        for p in ports:
            self.__fields_cross_reference_db.add(p)

    def fields_after_specific_time(self, cutoff_time):
        pipeline = [
            {"$unwind": "$data"},  # Flatten the 'data' array
            {"$match": {"data.date": {"$gt": cutoff_time}}},  # Filter by date
            {"$group": {"_id": "$port"}}  # Get unique ports
        ]
        # Run the aggregation
        result = list(self.__sio_db.ro[self.__comments_collection].aggregate(pipeline)) # type: ignore

        # Extract port names
        ports = [doc["_id"] for doc in result]
        return ports


    # def latest_updated_comment_time(self):
    # ''' example for last change with pipeline'''
    #     pipeline = [
    #         {"$unwind": "$data"},  # Flatten the data array
    #         {"$group": {
    #             "_id": None,
    #             "latest_date": {"$max": "$data.date"}
    #         }}
    #     ]
    #     # Run the aggregation
    #     result = list(
    #         self.__sio_db.ro[self.__comments_collection].aggregate(pipeline))

    #     # Extract the latest date
    #     latest_datetime = result[0]["latest_date"] if result else None
    #     return latest_datetime

    @staticmethod
    def get_comments_collection_name():
        return __class__.__comments_collection

    def __last_change_category(self):
        d = list(self.__sio_db.ro[self.__comments_collection].find( # type: ignore
            {'category.date': {'$exists': True}}, {'category': 1}).sort(
                'category.date', pymongo.DESCENDING).limit(1))
        if d is None or len(d) == 0:
            return None

        d = d[0].get('category', None)
        if d is None or len(d) == 0:
            return None
        d = d.get('date', None)
        return d

    def __last_change_comment(self):
        d = list(self.__sio_db.ro[self.__comments_collection].find( # type: ignore
            {'data.date': {'$exists': True}}, {'data': 1, 'data': {'$slice': -1}}).sort(
                'data.date', pymongo.DESCENDING).limit(1))
        if d is None or len(d) == 0:
            return None

        d = d[0].get('data', None)
        if d is None or len(d) == 0:
            return None
        d = d[0].get('date', None)
        return d

    def last_change(self):
        comment_change = self.__last_change_comment()
        category_change = self.__last_change_category()
        if comment_change is None:
            return category_change
        if category_change is None:
            return comment_change
        return max(category_change, comment_change)

    def add_comment(self, name, data: dict| None = None):
        name = self.__field_unification(name)
        '''other_data will be merged with data'''
        comment_to_add = {'data': data | {'date': datetime.datetime.now( # type: ignore
            datetime.timezone.utc)}} if 'date' not in data else data # type: ignore
        ret = self.__sio_db.rw[self.__comments_collection].find_one_and_update( # type: ignore
            {self.__field: name},
            {'$push': comment_to_add}, upsert=True)
        return ret

    def add_category(self, name, data: dict| None = None):
        name = self.__field_unification(name)
        '''other_data will be merged with data'''
        category_to_add = {'category': data | {'date': datetime.datetime.now( # type: ignore
            datetime.timezone.utc)}} if 'date' not in data else data # type: ignore
        ret = self.__sio_db.rw[self.__comments_collection].find_one_and_update( # type: ignore
            {self.__field: name},
            {'$set': category_to_add}, upsert=True)
        return ret

    def get_all_category(self, names: list[str] | None = None):
        data = dict()
        f = {'category': {'$exists': True, },
             self.__field: {'$exists': True, }}
        if names is not None and len(names) > 0:
            pnames = list(set(self.__field_unification(p) for p in names))
            f[self.__field]['$in'] = pnames # type: ignore

        for name in self.__sio_db.ro[self.__comments_collection].find(f, {self.__field: 1, 'category': 1}): # type: ignore
            if name.get('category', None) is not None:
                data[name[self.__field]] = name.get(
                    'category', {}).get('category', None)
        return data

    def get_all_fields(self):
        collection = self.__sio_db.ro[self.__comments_collection] # type: ignore
        documents = collection.find(
            {self.__field: {'$exists': True, }}, {self.__field: 1, })
        return [data.get(self.__field) for data in documents]

    def get_all_comments_last(self):
        data = dict()
        for name in self.__sio_db.ro[self.__comments_collection].find({'data': {'$exists': True, }, self.__field: {'$exists': True, }}, {self.__field: 1, 'data': {'$slice': -1, }}): # type: ignore
            if name.get('data', None) is not None:
                n = remove_icore_prefix(name[self.__field])
                if n not in data:
                    data[n] = name['data'][0]
                else:
                    # get latest data by date
                    if 'date' in data[n] and 'date' in name['data'][0]:
                        if data[n]['date'] < name['data'][0]['date']:
                            data[n] = name['data'][0]
                    else:
                        data[n] = name['data'][0]

        ret = dict()
        pnames = data.keys()
        done = dict()
        mindt = datetime.datetime(datetime.MINYEAR, 1, 1)
        for p in pnames:
            comment_to_ret = list()
            if p in done:
                ret[p] = ret[done[p]]
                continue
            for pp in self.__fields_cross_reference_db[p]:
                if pp in data:
                    comment_to_ret.append(data[pp])
                    done[pp] = p
            if len(comment_to_ret) > 0:
                ret[p] = sorted(comment_to_ret, key=lambda k: k.get(
                    'date', mindt), reverse=True)[0]
            else:
                ret[p] = None
        categories = self.get_all_category()
        for name in set(categories.keys()) | set(ret.keys()):
            if name not in ret or ret[name] is None:
                ret[name] = dict()
            ret[name] |= dict(category=categories.get(name, None))
        for k, v in ret.items():
            # if 'date' in v:
            #     v['date'] = v['date'].date()
            if 'by' in v:
                v['by'] = getpwuid(v['by'])
        return ret

    def __field_unification(self, name):
        ''' remove excess slashes '''
        return '/'.join([item for item in name.split('/') if item is not None and item != ''])


def parse_args():
    """ parse_args() : command-line parser """
    parser = argparse.ArgumentParser(
        description='SIO MOW permissions/comments handling via central DB')
    parser.add_argument('type',  option_strings=[
                        'comment', 'add_pt_server', 'bulk_insert'])
    parser.add_argument('-product_name', type=str,
                        default=os.getenv('PRODUCT_NAME'))
    parser.add_argument('-comments_file', type=str)
    args = parser.parse_args()
    return args


def parse_args_days():
    """ parse_args() : command-line parser """
    parser = argparse.ArgumentParser(
        description='Get usage statistics')
    parser.add_argument('-days', type=int, default=1)
    args = parser.parse_args()
    return args


def sio_add_session(session, product_name):
    uid = os.getuid()
    sdb = sio_db(product_name)
    to = 'sessions'
    session = session | dict(
        by=uid, date=datetime.datetime.now(datetime.timezone.utc))
    sdb.rw[to].insert_one(session)


def sio_add_usage(product_name, user, page, data):
    if product_name is None:
        product_name = 'UNKNOWN'
    if user is None:
        user = 'UNKNOWN'
    if page is None:
        page = 'UNKNOWN'
    if data is None:
        data = {}
    sdb = sio_db(product_name)
    to = 'usage'
    session = dict(
        by=user, page=page, date=datetime.datetime.now(datetime.timezone.utc), data=data)
    sdb.rw[to].insert_one(session)


def print_latest_usage(days):
    for n in sorted(sio_db.get_collection_names({'$regex': 'usage$'})):
        check_by_use(n.split('.')[0], days)

    # check_by_use('PNC78SERVER', days)
    # check_by_use('ryl_cpu', days)
    # check_by_use('CGC78CLIENT', days)
    # check_by_use('PNCN2H156P48', days)


def main():
    logger.info('Start')
    args = parse_args_days()
    days = args.days
    print_latest_usage(days)
    return 0
    if args.type == 'bulk_insert':
        if args.comments_file is None:
            raise 'No file given -comments_file'
            return 1
        df_comments, d = sio_mow_common.compress_df_by(
            sio_mow_common.mow_read_compare_models_report(args.comments_file)[[self.__field, 'comment']], self.__field)
        data_to_insert = dict()
        for index, row in df_comments.iterrows():
            comment = row['comment']
            if comment is not None and comment != "" and len(comment) > 1:
                data_to_insert[row[d]] = dict(comment=row['comment'])
        bulk_check_and_insert(data_to_insert, dict(
            by=os.getuid()), args.product_name)
    # sio_comments = sio_commnets()
    # test(sio_comments)
    # test2()
    # test3()
    # test4()
    return 0


def check_by_use(product_name, days):
    sdb = sio_db(product_name)
    to = 'usage'
    by_user = dict()
    by_page = dict()
    user_to_mail = dict()
    today = datetime.datetime.today()
    week_ago = today - datetime.timedelta(days=days)
    for d in sdb.ro[to].find({'date': {'$gte': week_ago}}):
        user = d['by']
        if user not in user_to_mail:
            u = get_phone(user)
            if u:
                user_to_mail[user] = u.split("@")[0]
        if user is None:
            continue
        page = d['page']
        if user not in by_user:
            by_user[user] = list()
        by_user[user].append(dict(page=page, date=d['date']))
        if page not in by_page:
            by_page[page] = Counter()
        by_page[page][user_to_mail.get(user, '?NA')] += 1
    # pprint.pp(by_user)
    k = pd.DataFrame.from_dict(by_page).fillna(0)
    if len(k):
        # add date and time
        print(f'\n{product_name} usage for last {days} days ({pd.to_datetime("now")}):')
        to_total = list(set(k.columns)-set(["/"]))
        if len(to_total):
            k['Total'] = k[to_total].sum(axis=1)
            k = k.sort_values(by='Total', ascending=False)
        k.loc[f'Total ({len(k)})', :] = k.sum(numeric_only=True, axis=0)

        print(tabulate.tabulate(k[sorted(k.columns)], # type: ignore
              headers='keys', tablefmt='psql'))


def get_phone(username):
    cmd = f'/usr/intel/pkgs/phonetools/2.0/bin/unix2outlook {username}'
    out = b''
    try:
        process = subprocess.Popen(
            cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = process.communicate()
        errcode = process.returncode
    except:
        pass
    return out.decode('ascii').strip()


def test9():
    sio_comments = sio_commnets('test', 'port')
    d = sio_comments.add_category(
        'par_ooo_vec/telemetry_bus_femnn1h_bp_clear124', dict(by=1126849, category='best path'))
    aa = sio_comments.get_all_comments_last()
    a = sio_comments.last_change()
    dd = sio_comments.get_all_category(['par_exe_int/accr_access_startmnnnh'])
    return


def test8():
    p = permissions()
    r4 = p.get_admins('test')
    r0 = p.user_add_request('test', 1, 'test message')
    r1 = p.user_get_request('test', 1)
    r2 = p.user_set_permission('test', 1, 11, p.write_roles[-1])
    r3 = p.user_set_permission('test', 1, 11268491, p.write_roles[-1])
    return p



def test4():
    a = sio_db('PNC78SERVER').get_latest_by_tag('daily')


def test_get_collection_names():
    a = sio_db.get_collection_names()
    return a


def test_view_permissions():
    a = permissions().user_has_view_permissions(11268491, 'PNC78SERVER')
    a = permissions().user_has_view_permissions(11268491, 'PNCN2H156P48')
    return a


def test3():
    a = permissions().user_can_comment(11268491, 'PNC78SERVER')
    sio_comments = sio_commnets('PNC78SERVER', 'port')
    b = sio_comments.get_all_comments_last(
        names=['par_meu/aglinadrld304orm305h_*_[*]']) # type: ignore
    return a


def add_category_uArch():
    df_ports = pd.read_csv(
        '/nfs/site/disks/ayarokh_wa/tmp/df_ports.uarchs.csv')[['port_compress', 'family']]
    done = dict()
    for i, row in df_ports[df_ports['family'].notnull()].iterrows():
        port = row['port_compress']
        p = port.removeprefix('icore0/')
        p = p.removeprefix('icore1/')
        if p not in done:
            data = dict(category=row['family'], by=11268491)
            done[p] = data
    sio_comments = sio_commnets('PNC78SERVER', 'port')
    for key, value in done.items():
        sio_comments.add_category(key, value)
    return 0


def read_category_uArch():
    from sio_mow_common import compress_df_by
    import re
    uArch_file = '/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/pnc_uarch_list.csv'
    ports_file = '/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/PNC/links/latest_pnc0a_1278_core_server_bu_postcts/runs/core_server/1278.6/sta_pt/spec.max_high.ttttcmaxtttt_100.tttt/logs/sio_mow_port_tns.csv'
    df_uarch = pd.read_csv(uArch_file)
    df_ports = pd.read_csv(ports_file)

    df_ports, compres_name = compress_df_by(df_ports, 'port')
    df_ports[f'ports_lower'] = df_ports['ports'].str.lower().str.replace('|', ' ')
    df_uarch['drv_signal_lower'] = df_uarch['drv_signal'].str.lower(
    ).str.replace('*', '.*')
    df_uarch['rcv_signal_lower'] = df_uarch['rcv_signal'].str.lower(
    ).str.replace('*', '.*')

    def fff(c):
        # ports = c.split(' ')
        for i, row in df_uarch[['drv_signal_lower', 'rcv_signal_lower', '#family']].iterrows():
            if re.search(row['drv_signal_lower'], c) and re.search(row['rcv_signal_lower'], c):
                return row['#family']
        return None
    df_ports['family'] = df_ports[f'ports_lower'].apply(fff)
    df_ports.to_csv('/nfs/site/disks/ayarokh_wa/tmp/df_ports.uarchs.csv')
    return


def debug_fields_cross_reference_db():
    a = sio_commnets('PNC78CLIENT', 'port')
    a.get_all_comments_last()
    start = time.perf_counter()
    ports = a.get_all_fields()
    end = time.perf_counter()
    print(f"Execution time: {end - start:.6f} seconds")
    start = time.perf_counter()
    b = fields_cross_reference_db()
    for p in ports:
        b.add(p)
    end = time.perf_counter()
    print(f"Execution time: {end - start:.6f} seconds")
    d1 = a.crd_get_latest_comments("icore0/par_meu/ml2dcsnpreqm500h[*]")
    d2 = a.crd_get_latest_comments("par_meu/ml2dcsnpreqm500h[*]")
    d3 = a.crd_get_latest_comments("ml2dcsnpreqm500h[*]")
    return 0


def debug_get_all_hsdes():
    hsd = hsdes()
    all_hsdes = hsd.get_all_hsdes('test')
    get_hsd_for_name = hsd.get_hsd_for_names(
        'test', ['icore1/par_ooo_vec/rortcompgm903h[*]'])
    return all_hsdes


def test_comment_latest_comment_data():
    # p = permissions()
    # r3 = p.user_set_permission('GFCN2CLIENT', 11268491, 11268491, p.write_roles[1],True)
    sio_comments = sio_commnets('PNC78CLIENT', 'port')
    data = sio_comments.last_change()
    print(data)
    data = sio_comments.crd_get_latest_comments("par_meu/ml2dcsnpreqm500h[*]")
    d= max([d['date'] for d in data])
    data = sio_comments.fields_after_specific_time(datetime.datetime.combine(d, datetime.datetime.min.time()))
    print(data)
    return data


if __name__ == '__main__':
    # test_comment_latest_comment_data()
    # debug_get_all_hsdes()
    # test_get_collection_names()
    # sys.exit(add_category_uArch())
    # debug_fields_cross_reference_db()
    sys.exit(main())
