#!/nfs/site/disks/ayarokh_wa/tools/python/virtualtest.3.11.1/bin/python3

import argparse
import os
import pprint
import sys
import dash

import flask
from modules import sio_mow_db
from dash import Dash, dcc, html, State
import dash_bootstrap_components as dbc

import modules.sio_mow_common as sio_mow_common
import modules.notification as notification
import logging

logger = logging.getLogger(__name__)
# logging.basicConfig(level=logging.ERROR)
def logger_init():
    formatter = '%(levelname)s:[%(asctime)s - %(filename)s:%(lineno)s - %(funcName)30s() ] %(message)s'
    logging.basicConfig(format=formatter)

user = os.getuid()
DEBUG = (user == 11268491)
DEBUG = False
logger.setLevel(logging.INFO if not DEBUG else logging.DEBUG)


class theMain:
    pages = dict()
    __title = None
    pt_data = dict()
    _id = 0

    def __init__(self, pt_data, server_port, local_only_commnets, tag, title, global_data):
        global app
        self.pt_data = pt_data
        if title is not None:
            self.__title = title
        if server_port is None or server_port == 0:
            server_port = sio_mow_common.find_free_port()
        self.__notification = notification.notification(id=self._id, listen_to={})
        app.layout = self.__make_app_layout(global_data)
        address = f'http://{os.getenv("HOST")}.{os.getenv("EC_SITE")}.intel.com:{server_port}'
        print(
            f'\n{"*"*100}\n\n  Open in a browser (chrome): {" "*5} {address}\n\n{"*"*100}')

        init_data = sio_mow_common.init_data(pt_data, logger)
        if not DEBUG:
            to_save = dict(
                pt=pt_data, address=address)
            if tag is not None:
                to_save['tag'] = tag
            if local_only_commnets:
                to_save['local_only_commnets'] = local_only_commnets
            sio_mow_db.sio_add_session(to_save, init_data['PRODUCT_NAME'])
        self.callbacks(app)
        app.run(debug=DEBUG, port=server_port,)

    def callbacks(self, app):
        self.__notification.callbacks(app)

    def __make_app_layout(self, global_data):
        ret = [dcc.Store(id='global_data', data=global_data)]
        if self.__title:
            ret.append(html.H1(self.__title))
        ret.append(self.__notification.get_layout())
        ret.append(dash.page_container)
        ret.append(dcc.Link('Open path explorer',
                   '/carpet_path_explorer', target="_blank",))
        return ret

    def user_can_view(self):
        username = flask.request.cookies.get('IDSID', None)
        user_has_view_permissions = sio_mow_db.permissions().user_has_view_permissions(
            username, self.ports_data.get_product_name)  # type: ignore
        return user_has_view_permissions, username


def parse_args():
    """ parse_args() : command-line parser """
    parser = argparse.ArgumentParser(
        description='Carpet:\nClock\nAnalysis\nRetiming\n   and\n   Propogation   with\n   Enhanced\nTracking')

    parser.add_argument('-new_file', type=str,
                        help='Input file port sum- current',  required=False, nargs='+')
    parser.add_argument('-old_file', type=str,
                        help='Input file port sum- prev', required=False, nargs='+')
    parser.add_argument('-comments_file', type=str,
                        help='Comments file', required=False)
    parser.add_argument('-out_file', type=str,
                        help='Output file', required=True)
    parser.add_argument('-pt_server_address', type=str,
                        help='PrimeTime session host', required=False, default='localhost')
    parser.add_argument('-pt_server_port', type=int,
                        help='PrimeTime session port', required=False, default=9901)
    parser.add_argument('-server_port', type=int,
                        help='Shell server port', required=False, default=0)
    parser.add_argument('-tag', help='tag for session',
                        type=str,  required=False)
    parser.add_argument('-title', help='Top title for session',
                        type=str,  required=False)
    parser.add_argument('-local_only_comments',
                        help='If ON comments will not be pushed to the central DB', required=False, action='store_true')
    args = parser.parse_args()
    return args


def main():
    global app 
    global server
    args = parse_args()
    fin_new = args.new_file
    fin_old = args.old_file
    comments = args.comments_file
    output_file = args.out_file
    pt_server = args.pt_server_address
    pt_port = args.pt_server_port
    server_port = args.server_port
    local_only_comments = args.local_only_comments
    title = args.title
    tag = args.tag
    t = f'Carpet: {title}' if title else 'Carpet'
    app = Dash(__name__, update_title=None, title=t, external_stylesheets=[
               dbc.themes.BOOTSTRAP, dbc.icons.BOOTSTRAP], use_pages=True, routing_callback_inputs={'global_data': State('global_data', 'data')})  # type: ignore
    server = app.server
    logger.info(args._get_args())
    pt_data = {'address': pt_server, 'port': pt_port}
    global_data = {
        'fin_new': fin_new,
        'fin_old': fin_old,
        'comments': comments,
        'output_file': output_file,
        'pt_data': pt_data,
        'server_port': server_port,
        'local_only_comments': local_only_comments,
        'tag': tag,
    }
    theMain(pt_data, server_port, local_only_comments, tag, title, global_data)
    return 0


if __name__ == '__main__':
    # logger_init()
    sys.exit(main())
