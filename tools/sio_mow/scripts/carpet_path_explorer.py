#!/nfs/site/disks/ayarokh_wa/tools/python/virtualtest.3.11.1/bin/python3

import sys
import dash
from dash import Dash, dcc, html, State, Input
import dash_bootstrap_components as dbc
from os.path import dirname

import modules.notification as notification


DEBUG = False
PORT = 8050
class theMain:
    _id = 0
    def __init__(self,app):
        self.__notification = notification.notification(id=self._id, listen_to={})
        app.layout = self.__make_app_layout()
        app.run(debug=DEBUG, port=PORT,)
    def callbacks(self, app):
        self.__notification.callbacks(app)
    def __make_app_layout(self):
        ret = [dcc.Store(id='global_data', data={})]

        ret.append(self.__notification.get_layout())
        ret.append(dash.page_container)
        return ret

if __name__ == "__main__":
    app = Dash(__name__, update_title=None, title='Carpet path explorer', external_stylesheets=[
               dbc.themes.BOOTSTRAP, dbc.icons.BOOTSTRAP], use_pages=True, pages_folder='pages2', routing_callback_inputs={'global_data': State('global_data', 'data')})  # type: ignore
    theMain(app)
    