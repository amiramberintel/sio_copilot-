#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3
import logging
import pprint
import random
import re
import string
from modules import sio_mow_comments 
# FIELD, compress_port, compress_ports
from modules import sio_mow_db
from dash import Dash, html, callback, Output, Input, State, ALL, MATCH, dcc, no_update, clientside_callback, ctx, ClientsideFunction
from dash.exceptions import PreventUpdate
import dash_bootstrap_components as dbc
# import dash_dangerously_set_inner_html

def logger_init():
    formatter = '%(levelname)s:[%(asctime)s - %(filename)s:%(lineno)s - %(funcName)30s() ] %(message)s'
    logging.basicConfig(format=formatter)

logger = logging.getLogger(__name__)
logger.setLevel(logging.ERROR)

class hsdes:
    __id: int
    __hsdes_top = 'hsdes_top'
    __hsdes_top_modal_container = 'hsdes_top_modal_container'
    __hsdes_top_open_modal_button = '__hsdes_top_open_modal'

    def __init__(self, id=0, overall_data=None, stores_data=None, data_for_comment=None) -> None:
        self.__id = id
        self.__overall_data = overall_data
        self.__hsdbody = modal_body(
            id=id, overall_data=overall_data, stores_data=stores_data)
        self.__data_for_comment = data_for_comment

    def layout(self) -> html.Div:
        button = dbc.Button(
            "Open HSD", id={'type': self.__hsdes_top_open_modal_button, 'index': self.__id})
        ret = html.Div(
            [
                button, 
                dbc.Modal(id={'type': self.__hsdes_top_modal_container, 'index': self.__id},is_open=False, size="xl",),
             ], 
             id={'type': self.__hsdes_top, 'index': self.__id})
        return ret

    def callbacks(self, app: Dash):
        app.callback(
            output={
                "modal": Output({'type': self.__hsdes_top_modal_container, 'index': MATCH}, 'children'),
                "is_open": Output({'type': self.__hsdes_top_modal_container, 'index': MATCH}, 'is_open')
                 },
            inputs={
                'n_clicks': Input({'type': self.__hsdes_top_open_modal_button, 'index': MATCH}, 'n_clicks'),
                'overall_data': State({'type': self.__overall_data, 'index': MATCH}, 'data')},
            prevent_initial_call=True)(self.__make_modal)
        self.__hsdbody.callbacks(app, self.__data_for_comment)

    def __make_modal(self, n_clicks, overall_data):
        ret = dict(modal=no_update, is_open=no_update)
        if overall_data is not None:
            project = overall_data.get('PRODUCT_NAME')
            ret['modal'] = self.__modal_get(project)  # type: ignore
            ret['is_open'] = True # type: ignore
        return ret

    def __modal_get(self, project) -> list[html.Div]:
        modal = [
            self.__modal_get_header(),
            self.__modal_get_body(project),
            # self.__modal_get_footer(),
        ]
        return modal

    def __modal_get_header(self) -> dbc.ModalHeader:
        return dbc.ModalHeader(dbc.ModalTitle('Open HSD'))

    def __modal_get_body(self, project) -> dbc.ModalBody:
        body = self.__hsdbody.layout(project)
        return dbc.ModalBody(body)

    def __modal_get_footer(self) -> dbc.ModalFooter:
        close = dbc.Button('Close', id={
            'type': 'hsdes_modal_close', 'index': self.__id}, className='ms-auto', n_clicks=0)
        addhsd = dbc.Button('Add HSD', id={
            'type': 'hsdes_modal_addhsd', 'index': self.__id}, className='ms-auto', n_clicks=0)
        footer = html.Div([close, addhsd])
        return dbc.ModalFooter(footer)


class modal_body:
    __hsdes_db: sio_mow_db.hsdes
    __body_for_hsd = 'big_body'
    __hsd_form = 'hsd_form'
    __hsd_commit_button = '__hsd_commit_button'
    __hsd_commit_output = '__hsd_commit_output'
    __choose_ar = 'choose_ar'
    __hsd_store = 'modal_body_hsd_store'
    __hsd_store_id = 'modal_body_hsd_store_id'
    __id: int
    __data_from_session: str | None
    __stores_data: list | None

    def __init__(self, id: int, overall_data, stores_data=None) -> None:
        self.__hsdes_db = sio_mow_db.hsdes()
        self.__id = id
        self.__data_from_session = overall_data
        self.__stores_data = stores_data

    def layout(self, project) -> html.Div:
        options = []
        for ar in self.__get_from_db_config(project):
            id = ar.get('id', None)
            name = ar.get('name', id)
            if name is not None:
                options.append({'label': name, 'value': id})
        ret = [
            dbc.Label('Choose one'),
            dbc.RadioItems(options=options, id={
                           'type': self.__choose_ar, 'index': self.__id}),
            html.Div(id={'type': self.__body_for_hsd, 'index': self.__id})]
        store = dcc.Store(id={'type': self.__hsd_store,
                          'index': self.__id})
        store_id = dcc.Store(
            id={'type': self.__hsd_store_id, 'index': self.__id})
        ret.append(store)
        ret.append(store_id)
        return html.Div(ret)

    def callbacks(self, app: Dash, data_for_comment):
        s = [State({'type': id, 'index': MATCH}, 'data')
             for id in self.__stores_data] if self.__stores_data else []
        # chose hsd type
        app.callback(
            output=[
                {"body": Output({'type': self.__body_for_hsd, 'index': MATCH}, 'children')}],
            inputs=[
                {"choose_ar": Input({'type': self.__choose_ar, 'index': MATCH}, 'value')}],
            state=[{'data_from_session': State({'type': self.__data_from_session, 'index': MATCH}, 'data')},
                   ],
            prevent_initial_call=True)(self.__make_page_layout)

        # hsd commit in browser
        clientside_callback(
            ClientsideFunction(
                namespace='hsdes',
                function_name='CreateArticle'
            ),
            Output({'type': self.__hsd_store_id, 'index': MATCH}, 'data'),
            Input({'type': self.__hsd_store, 'index': MATCH}, 'data'),
            *s,
        )

        # hsd validate
        app.callback(
            output=[
                Output({'type': self.__hsd_form, 'index': MATCH,
                       'hsd_name': ALL}, 'className'),
                {"hsd_data": Output(
                    {'type': self.__hsd_store, 'index': MATCH}, 'data'),
                "button": Output(
                {'type': self.__hsd_commit_button, 'index': MATCH}, 'disabled',allow_duplicate=True),}
            ],
            inputs={
                "n_clicks": Input({'type': self.__hsd_commit_button, 'index': MATCH}, 'n_clicks'),
                'overall_data': State({'type': self.__data_from_session, 'index': MATCH}, 'data'),
                "choose_ar": State({'type': self.__choose_ar, 'index': MATCH}, 'value'),
                'values': State({'type': self.__hsd_form, 'index': MATCH, 'hsd_name': ALL}, 'value'),},
            prevent_initial_call=True)(self.__validate_hsd)
        app.callback(
            output={"hsd_commit_output": Output({'type': self.__hsd_commit_output, 'index': MATCH}, 'children'),
                    "button": Output({'type': self.__hsd_commit_button, 'index': MATCH}, 'disabled',allow_duplicate=True)},
            inputs={"hsd_ret": Input({'type': self.__hsd_store_id, 'index': MATCH}, 'data')},
            state={
                'session_data': State({'type': self.__data_from_session, 'index': MATCH}, 'data'),
                'ports_data': State({'type': data_for_comment, 'index': MATCH}, 'data')},
            prevent_initial_call=True)(self.__hsd_make_output)

    def __hsd_make_output(self, hsd_ret, session_data, ports_data):
        ret = ""
        
        if hsd_ret is None:
            raise PreventUpdate
        if 'error' in hsd_ret:
            ret = hsd_ret.get('error')
        new_id = hsd_ret.get('data', {}).get('new_id', None)
        button = False
        if new_id:
            pn = session_data.get('PRODUCT_NAME', 'UNKNOWN')
            port = ports_data.get(sio_mow_comments.FIELD)
            if port:
                if isinstance(port, list):
                    port = sio_mow_comments.compress_ports(port)
                else:
                    port = sio_mow_comments.compress_port(port)
            self.__hsdes_db.save_hsdes_id_to_db(pn, {'hsd_id': new_id}, port)
            href = f'https://hsdes.intel.com/appstore/article/#/{new_id}'
            ret = html.A(href, href=href,
                         disable_n_clicks=True, target="_blank")
            button = True
        return dict(hsd_commit_output= ret,button=button)

    def __validate_hsd(self, n_clicks, overall_data, choose_ar, values):
        if n_clicks is None:  # type: ignore
            raise PreventUpdate
        ret = []
        hsd_data = {}
        project = overall_data.get('PRODUCT_NAME')
        config_by_id = self.__get_config_by_id(choose_ar, project)
        if config_by_id is None:
            config_by_id = {}
        data_config_by_id = config_by_id.get('gui', {}).get('elements', [])
        for cc in ctx.args_grouping.get('values', []): # type: ignore
            name = cc.get('id').get('hsd_name')
            filtered_data = [d for d in data_config_by_id if d['id'] == name]
            if len(filtered_data) and not filtered_data[0].get('required',False):
                ret.append('valid')
                continue
            value = cc.get(cc.get('property'))
            if isinstance(value, str):
                value = value.strip()
                
            is_valid = "is-invalid" if value is None or value == "" else "valid"
            ret.append(is_valid)
            hsd_data[name] = value

        ret_data = dict(
            hsd_data = {'payload': self.__validate_hsd_make_payload(hsd_data)} 
            if all([x=='valid' for x in ret]) else no_update,
            button = all([x=='valid' for x in ret])
            )
        r = [ret, ret_data]
        return r

    def __validate_hsd_make_payload(self, data: dict) -> dict:
        ret = dict()
        ret['tenant'] = data.pop('tenant')
        ret['subject'] = data.pop('subject')

        ret['fieldValues'] = []
        for k, v in data.items():
            ret['fieldValues'].append({k:v})
        # logger.debug(f"validate_hsd_make_payload: {ret}")
        return ret

    def __get_config_by_id(self, id, project):
        for x in self.__get_from_db_config(project):
            if x.get("id", None) == id:
                return x
        return None

    def __make_page_layout_text(self, id, placeholder, def_value, required, options):
        datalist_options_id = ''.join(random.choices(
            string.ascii_uppercase + string.digits, k=30))
        input_dict = dict(id={'type': self.__hsd_form, 'index': self.__id, 'hsd_name': id},
                      placeholder=placeholder, type="text", invalid=False, value=def_value)
        if options:
            input_dict['list'] = datalist_options_id
        if required:
            input_dict['required'] = required
        l = dbc.Input(**input_dict) # type: ignore
        ret = [dbc.Label(id), l, dbc.FormFeedback(f"Please enter {id}", type="invalid") if required else None]
        if options:
            ret.append(html.Datalist([html.Option(o)
                       for o in options], id=datalist_options_id))
        return ret

    def __make_page_layout_textarea(self, id, placeholder, def_value, required):
        l = dbc.Textarea(id={'type': self.__hsd_form, 'index': self.__id, 'hsd_name': id},
                         placeholder=placeholder, invalid=False, required=required, value=def_value,)
        ret = [dbc.Label(id), l, dbc.FormFeedback(
            f"Please enter {id}", type="invalid")]
        return ret

    def __make_page_layout_radio(self, id, def_value, options):
        l = [{"label": str(ee), "value": ee} for ee in options]

        ret = [dbc.Label(id),
               dbc.RadioItems(id={'type': self.__hsd_form, 'index': self.__id, 'hsd_name': id}, options=l, value=def_value)] # type: ignore
        ret.append(dbc.FormFeedback(
            f"Please select one of {id}", type="invalid"))
        return ret

    def __make_page_layout_select(self, id, def_value, required, options):
        l = [{"label": ee, "value": ee} for ee in options]
        ret = [dbc.Label(id),
               dbc.Select(id={'type': self.__hsd_form, 'index': self.__id, 'hsd_name': id}, options=l, value=def_value, required=required)] # type: ignore
        ret.append(dbc.FormFeedback(
            f"Please select one of {id}", type="invalid"))
        return ret

    def __make_page_layout(self, data: dict, data_from_session: dict, defaults: dict = dict(send_mail=False, priority='3-medium')):
        if data_from_session is None:
            raise PreventUpdate
        project = data_from_session.get(
            'data_from_session', {}).get('PRODUCT_NAME')
        if project is None:
            raise PreventUpdate
        auto_data = ['tenant', 'subject']
        config = self.__get_config_by_id(data['choose_ar'], project)
        ret = []
        body = None
        if config:
            title = config.get('gui', {}).get('title', None)
            if title:
                ret.append(
                    dbc.Row(dbc.Col(html.Div(title)), className="mb-3",))
            read_only_fields = []
            for a in auto_data:
                if a in config.get('hsd', {}):
                    read_only_fields.append(dbc.Col(html.Div([dbc.Label(a), dbc.Input(
                        id={'type': self.__hsd_form, 'index': self.__id, 'hsd_name': a}, type="text", value=config.get('hsd', {}).get(a), disabled=True)])))
            if read_only_fields:
                ret.append(dbc.Row(read_only_fields, className="mb-3",))
            c = config.get('gui', {}).get('elements', {})
            for e in c:
                id = e.get('id')
                def_value = defaults.get(id, None)
                def_value = def_value if def_value is not None else e.get('value', None)
                placeholder = e.get('placeholder', None)
                required = e.get('required', False)
                options = e.get('choises', [])
                t = e.get('type', None)
                ll = None
                if t == 'text':
                    ll = self.__make_page_layout_text(
                        id, placeholder, def_value, required, options)
                elif t == 'textarea':
                    if id == 'description':
                        if def_value is None:
                            def_value = ""
                    ll = self.__make_page_layout_textarea(
                        id, placeholder, def_value, required)
                elif t == 'select':
                    ll = self.__make_page_layout_select(
                        id, def_value, required, options)
                elif t == 'radio':
                    ll = self.__make_page_layout_radio(id, def_value, options)
                if ll:
                    ret.append(
                        dbc.Row(dbc.Col(html.Div(ll)), className="mb-3",))
            ret.append(dbc.Row(dbc.Col(dbc.Button("add hsd", color="primary", className="me-1",
                       id={'type': self.__hsd_commit_button, 'index': self.__id})), className="mb-3",))
            ret.append(dbc.Row(
                dbc.Col(
                    html.Div(id={'type': self.__hsd_commit_output, 'index': self.__id})
                                
                    ), className="mb-3",))
            body = html.Div(html.Div(dcc.Loading(children=ret  , delay_show=600, overlay_style={"visibility": "visible", "opacity": .5, "backgroundColor": "white"})))
        return [dict(body=body)] # type: ignore

    def __make_page_layout_additional_data(self, data, data2) -> str:
        ret = "\n\n\n"
        ret += '-'*50 + ' Dont edit after this line' + '-'*50
        if data and 'command_runned' in data:
            ret += '\n\n\ncommand_runned: ' + str(data.get('command_runned'))
        if data2:
            ret += "\n\n\n" + pprint.pformat(data2)
        return ret

    def __get_from_db_config(self, project) -> list[dict]:
        return self.__hsdes_db.get_gui_from_db(project)


if __name__ == '__main__':
    logger_init()
    app = Dash(__name__, external_stylesheets=[
               dbc.themes.BOOTSTRAP, dbc.icons.BOOTSTRAP])
    hsd = hsdes()
    # r = runner(server='localhost:9901')
    # r = runner()
    app.layout = hsd.layout()
    hsd.callbacks(app)
    app.run(debug=True, port='8011')
