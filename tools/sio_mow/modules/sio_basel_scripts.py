#!/nfs/site/disks/ayarokh_wa/tools/python/3.11.1/bin/python3

import json
import logging
import pprint
import re
import uuid
from dash import MATCH, dash, Dash, dcc, html, Input, Output, State, ALL, ctx, no_update
from dash.exceptions import PreventUpdate

import dash_bootstrap_components as dbc


def logger_init():
    formatter = '%(levelname)s:[%(asctime)s - %(filename)s:%(lineno)s - %(funcName)30s() ] %(message)s'
    logging.basicConfig(format=formatter)


logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


class bassel_scripts:
    def __init__(self, id) -> None:
        self.__id = id

    def callbacks(self, app, listen_to):
        app.callback(
            output=dict(output=Output(
                {'type': f'sio_bassel_control', 'index': self.__id, }, 'data')),
            inputs=dict(n_clicks=Input({'type': f'sio_bassel_control_internal', 'sub_type': 'run', 'index': ALL}, 'n_clicks'),
                        state=State({'type': f'sio_bassel_control_internal',
                                    'sub_type': 'input', 'index': ALL}, 'value'),
                        append=State({'type': f'sio_bassel_control_internal',
                                     'sub_type': 'append', 'index': ALL}, 'value'),
                        command=State({'type': f'sio_bassel_control_internal',
                                      'sub_type': 'command', 'index': ALL}, 'value'),
                        ),
            prevent_initial_call=True,
        )(self.__callback)
        app.callback(
            output=dict(output=Output(
                {'type': 'sio_bassel_control_internal_list', 'index': MATCH}, 'children')),
            inputs=dict(data=Input({'type': f'{listen_to}',  'index': MATCH}, 'data'),
                        state=State({'type': 'sio_bassel_control_internal_list', 'index': MATCH}, 'children')),
            prevent_initial_call=True,
        )(self.__callback_list)

    def __callback_list_parse(self, data):
        if data is None:
            return ''
        try:
            return re.sub(r"[^\w\s\[\]/]", "", data.get('value', ''))
        except Exception as e:
            logger.error(f'Error parsing data: {e}: {data.get("value", "")=}')
            return ''

    def __callback_list(self, data, state):
        if data is None:
            raise PreventUpdate

        r = []
        done = set()
        if state:
            for v in state:
                d = v.get('props', {}).get('value', None)
                if d:
                    if d not in done:
                        r.append(html.Option(value=d))
                        done.add(d)
                    

        cleaned = self.__callback_list_parse(data)
        for v in cleaned.split():
            if v not in done:
                done.add(v)
                r.append(html.Option(value=v))
        ret = dict(output=no_update)
        if r:
            ret = dict(output=r)
        # logger.debug(f'{ret=}')
        return ret

    def get_layout(self, bassel_script_list=None):
        # logger.debug(f'{bassel_script_list=}')
        what = ['pins', 'cells', 'ports', 'nets']
        radios = dbc.RadioItems(options=what, value=what[0], inline=True, id=dict(
            type=f'sio_bassel_control_internal', sub_type='input', index='what'),)
        lists = [html.Option(value=v, title=v) for v in set(self.__callback_list_parse(
            bassel_script_list).split()) if v] if bassel_script_list else None
        ig = dbc.InputGroup([
            # dbc.InputGroupText('Pattern'),
            dbc.Input(id=dict(type=f'sio_bassel_control_internal', sub_type='input', index='input'), placeholder="Type pin/cell/port pattern to draw", type="text",
                      list=json.dumps({'index': self.__id, 'type': 'sio_bassel_control_internal_list'}, sort_keys=True, separators=(',', ':'))),
            html.Datalist(
                lists, id={'index': self.__id, 'type': 'sio_bassel_control_internal_list'}),
            dbc.InputGroupText(
                dbc.Checkbox(label="Append", value=False, id=dict(
                    type=f'sio_bassel_control_internal', sub_type='input', index='append'))
            ),
        ])
        ret = [ig, radios] + self.__get_layout_buttons() + \
            [dcc.Store(id=dict(type=f'sio_bassel_control',
                       index=self.__id), data=dict())]
        return dbc.Stack(ret, gap=2, direction="vertical")

    def __callback(self, n_clicks, state, command, append):
        # logger.debug(f'callback input: {pprint.pformat(ctx.states_list)}')
        # logger.debug(f'callback input: {pprint.pformat(ctx.triggered_prop_ids)}')
        triggered = list(ctx.triggered_prop_ids.values())[0] if len(
            list(ctx.triggered_prop_ids)) > 0 else None
        if not triggered:
            raise PreventUpdate
        # logger.debug(f'callback input: {pprint.pformat(ctx.states_list)}')
        to_run = dict(args=list(), what=None, input=None,
                      append=False, command=None)
        for k in ctx.states_list:
            if isinstance(k, list):
                for kkk in k:
                    kk = kkk['id']
                    value = kkk.get('value', None)
                    if kk['index'] == 'input':
                        to_run['input'] = value
                    if kk['index'] == 'what':
                        to_run['what'] = value
                    if kk['index'] == 'append':
                        to_run['append'] = value
                    if kk['index'] == triggered['index']:
                        if kk.get('sub_type', '') == 'command':
                            to_run['command'] = value
                        elif value:
                            to_run['args'].extend(value)  # type: ignore
        ret = dict(output=to_run)
        # logger.debug(f'{ret=}')
        return ret

    def __get_layout_buttons(self):
        tooltips = list()
        ret = list()
        for key, val in self.__get_layout_buttons_db().items():
            checkboxes = dict(options=[], value=[], inline=True,
                              id=dict(type=f'sio_bassel_control_internal', sub_type='input', index=key))
            for k, v in val['controls'].items():
                id = uuid.uuid4().hex
                if v['type'] == 'checkbox':
                    checkboxes['options'].append(  # type: ignore
                        {'value': v['name'], 'label': html.Div(k, id=id), })
                    if v.get('value', False):
                        checkboxes['value'].append(v['name'])  # type: ignore
                if v.get('help', None):
                    tooltips.append(dbc.Tooltip(
                        v['help'], target=id, style={'fontSize': '0.8em'}))
            button = html.Div(dbc.Button(val['name'],  id=dict(
                type=f'sio_bassel_control_internal', sub_type='run', index=key), outline=True, color="secondary", size="sm"), className="d-grid")
            command = val['command']
            ret.append(dbc.Form(
                dbc.Row(
                    [dbc.Col(button), dbc.Col(
                        dbc.Checklist(**checkboxes), width="auto"), dcc.Input(type='hidden', id=dict(type=f'sio_bassel_control_internal', sub_type='command', index=key), value=command)],  # type: ignore
                    align="center", justify="between",),
                className="mb-3",
            ))
        # diable tooltips for now
        tooltips = None
        return [dbc.Stack(ret), html.Div(tooltips if tooltips else [])]

    @staticmethod
    def __get_layout_buttons_db():
        ret = dict()
        ret['fanin'] = dict(name='Draw Fanin', command='sio_draw_fanin',
                            controls=dict(
                                 startpoints_only=dict(
                                     name='-startpoints_only', type='checkbox', value=True, help='Find only the timing startpoints'),
                                 only_cells=dict(
                                     name='-only_cells', type='checkbox', value=False, help='Return cells rather than pins'),
                                 flat=dict(name='-flat', type='checkbox',
                                           value=True, help='Hierarchy is ignored'),
                            )
                            )
        ret['fanout'] = dict(name='Draw Fanout', command='sio_draw_fanout',
                             controls=dict(
                                 endpoints_only=dict(
                                     name='-endpoints_only', type='checkbox', value=True, help='Find only the timing startpoints'),
                                 only_cells=dict(name='-only_cells', type='checkbox',
                                                 value=False, help='Return cells rather than pins'),
                                 flat=dict(name='-flat', type='checkbox',
                                           value=True, help='Hierarchy is ignored'),
                                 clock_tree=dict(
                                     name='-clock_tree', type='checkbox', value=False, help='Return list of clock tree components'),
                             )
                             )
        ret['draw'] = dict(name='Draw', command='sio_draw_points',
                           controls=dict(
                               hierarchical=dict(name='-hierarchical', type='checkbox',
                                                 value=False, help='Search level-by-level in current instance'),
                               leaf=dict(name='-leaf', type='checkbox', value=False,
                                         help='Get leaf/global pins of nets with -of_objects'),
                               regexp=dict(name='-regexp', type='checkbox', value=False,
                                           help='Perform case-insensitive matching'),
                               exact=dict(name='-exact', type='checkbox', value=False,
                                          help='Wildcards are considered as plain characters'),
                           )
                           )

        return ret


if __name__ == '__main__':
    logger_init()
    bassel_scripts = bassel_scripts()  # type: ignore
    ret = bassel_scripts.get_layout()  # type: ignore
    exit(0)
