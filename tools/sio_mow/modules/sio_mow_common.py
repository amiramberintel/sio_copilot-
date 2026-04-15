from contextlib import closing
import gzip
import io
import pathlib
import pprint
from pwd import getpwnam
import re
import socket
import subprocess
import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import dash_ag_grid as dag
import dash
import dash_bootstrap_components as dbc


class init_data:
    data = dict(errors=None, warnings=None, data=dict())
    messages = []
    pt_server = None
    log = None
    is_ohad = False

    def __init__(self, pt_server, log) -> None:
        self.is_ohad = isinstance(pt_server, str)
        self.pt_server = pt_server
        self.get_init_data_from_pt()
        self.log = log

    @property
    def init_data(self):
        return self.data.get('data', None)
    def __getitem__(self, key):
        return self.data.get('data', {}).get(key, None) # type: ignore
    @property
    def problems(self):
        return self.messages

    def get_init_data_from_pt(self):
        self.messages.clear()
        errors = ''
        warnings = ''
        if not self.is_ohad:
            pt_server = self.pt_server['address']  # type: ignore
            pt_port = self.pt_server['port']  # type: ignore
            errors, warnings, report = parse_data_from_server(get_data_from_pt_server(
                f'sio_mow_get_initial_data', pt_server, pt_port), self.log)

        else:
            errors, warnings, report = parse_data_from_server(get_data_from_pt_server_ohad(
                f'server_run_cmd_ohad sio_mow_get_initial_data', self.pt_server), self.log)
        if errors:
            for e in errors:
                self.messages.append(
                    dict(title="Error!", message=e, color='red', action="show", autoClose=False))

        if warnings:
            for e in warnings:
                self.messages.append(
                    dict(title="Warning!", message=e, color='red', action="show"))
        data = dict()
        for t in report['text']:
            if t:
                for ts in t:
                    ts = ts.strip()
                    if ts:
                        _ = ts.split(" ")
                        tt = _[0]
                        val = " ".join(_[1:])
                        data[tt.strip()] = val.strip()
        self.data['data'] = data
        # pprint.pp(data)


class svg_core:
    transform_per_template = None
    scale_nm = 1000

    def __init__(self, root=None, tag=None, defs_dir=None, transform_per_template=None):
        import get_points_from_def
        if transform_per_template is not None:
            self.transform_per_template = transform_per_template
        else:
            self.transform_per_template = get_points_from_def.def_loc(
                tag=tag, defs_dir=defs_dir, root=root).transform_per_template  # type: ignore

    def shape_exp(self, points):
        res = []
        max_x = 0
        max_y = 0
        for a, b in list(zip(points[::2], points[1::2])):
            x = int(a)
            y = int(b)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
            res.append(str(x) + ',' + str(y))
        return ' '.join(res), max_x, max_y

    def get_fig(self):
        return self.shape_svg_for_go()
    
    @staticmethod
    def oasis_transform_invert(T, x, y):
        T_inv = np.linalg.inv(T)
        x, y, _ = T_inv @ [x, y, 1]
        return x, y

    @staticmethod
    def oasis_transform_to_matrix_6(flip, angle, x, y):
        T = np.eye(3)

        # Flip
        if flip == 'flip_y':
            T = np.array([[-1, 0, 0],
                        [ 0, 1, 0],
                        [ 0, 0, 1]]) @ T
        elif flip == 'flip_x':
            T = np.array([[ 1, 0, 0],
                        [ 0,-1, 0],
                        [ 0, 0, 1]]) @ T
        elif flip == 'flip_both':
            T = np.array([[-1, 0, 0],
                        [ 0,-1, 0],
                        [ 0, 0, 1]]) @ T

        # Rotate
        if angle == 'rotate_90':
            T = np.array([[ 0, -1, 0],
                        [ 1,  0, 0],
                        [ 0,  0, 1]]) @ T
        elif angle == 'rotate_180':
            T = np.array([[-1,  0, 0],
                        [ 0, -1, 0],
                        [ 0,  0, 1]]) @ T
        elif angle == 'rotate_270':
            T = np.array([[ 0, 1, 0],
                        [-1, 0, 0],
                        [ 0, 0, 1]]) @ T

        # Translate
        T = np.array([[1, 0, x],
                    [0, 1, y],
                    [0, 0, 1]]) @ T

        return T

    def svg_add_points(self, data={}, data_df_list=None):
        res = []
        for color, points in data.items():
            if points and len(points) > 0:
                ppls = dict()
                for p in points:
                    for pp in p:
                        ppl = pp.strip().split(" ")
                        if len(ppl) > 2:
                            s = None
                            for i in range(0, len(ppl), 2):
                                if ppl[0] == "" or ppl[1] == "":
                                    continue
                                pplf0 = float(ppl[i])
                                pplf1 = float(ppl[i+1])

                                e = [pplf0, pplf1]
                                if s:
                                    ppls[f'{"_".join([str(x) for x in s])},{"_".join([str(x) for x in e])}'] = [
                                        s, e]
                                s = e
                for ppl in ppls.values():
                    res.append(dict(type='line', xref='x', yref='y',
                               x0=ppl[0][0], y0=ppl[0][1], x1=ppl[1][0], y1=ppl[1][1], line=dict(color=color, width=2,)))
        return self.shape_svg_for_go(lines_to_add=res, data_df_list=data_df_list)

    def get_shapes_ebbs(self):
        max_x = max_y = 0

        shapes = []
        ebbs_shapes = dict(x=[], y=[], inst=[])
        data = self.transform_per_template
        data = dict(
            sorted(data.items(), key=lambda item: item[1][0]['depth'], reverse=False)) # type: ignore
        for par, ds in data.items():
            for d in ds:
                # pprint.pp(d)
                points = d.get('shape', None)
                matrix = __class__.oasis_transform_to_matrix_6(
                    d['flip'], 0, int(d['x'])/self.scale_nm, int(d['y'])/self.scale_nm)
                if points:
                    path, x, y = self.shape_exp_go(points, matrix)
                    max_x = max(x, max_x)
                    max_y = max(y, max_y)
                    shapes.append({'type': 'path', 'path': path + ' Z',
                                   'line_color': "RoyalBlue", 'fillcolor': "PaleTurquoise", 'label': dict(text=par), 'opacity': 0.2})
                if 'ebbs' in d:
                    i = 0
                    for ebb in d['ebbs']:
                        instname = ebb.get('inst', '').split('/')[-1]
                        points = ebb['coords']
                        i = len(ebbs_shapes['x']) if len(
                            ebbs_shapes['x']) > 0 else 0
                        for a, b in list(zip(points[::2], points[1::2])):
                            x, y, _ = matrix @ [float(a), float(b), 1]
                            ebbs_shapes['x'].append(x)
                            ebbs_shapes['y'].append(y)
                            ebbs_shapes['inst'].append(None)
                        ebbs_shapes['x'].append(ebbs_shapes['x'][i])
                        ebbs_shapes['y'].append(ebbs_shapes['y'][i])
                        ebbs_shapes['inst'].append(instname)

                        ebbs_shapes['x'].append(None)
                        ebbs_shapes['y'].append(None)
                        ebbs_shapes['inst'].append(None)
        return shapes, ebbs_shapes, max_x, max_y

    def shape_svg_for_go(self, lines_to_add=None, data_df_list=None):

        shapes, ebbs_shapes, max_x, max_y = self.get_shapes_ebbs()
        if lines_to_add:
            shapes.extend(lines_to_add)
        img = np.full((int(max_y), int(max_x)), 0)
        img = np.zeros([int(max_y), int(max_x), 4], dtype=np.uint8)
        fig = px.imshow(img, binary_string=True,)
        fig.update_xaxes(range=[0, max_x], constrain="domain", showspikes=True,
                         spikemode="across", spikedash="dot", spikethickness=-2, spikecolor='blue')
        fig.update_yaxes(range=[0, max_y], constrain="domain", scaleanchor="x", scaleratio=1,
                         showspikes=True, spikemode="across", spikedash="dot", spikethickness=-2, spikecolor='blue')
        fig.update_traces(hovertemplate="  x: %{x} y: %{y}<extra></extra>")
        # fig.add_scatter(x=ebbs_shapes['x'], y=ebbs_shapes['y'], fill="toself", line={'color':'RoyalBlue','width':0},opacity=0.3,
        #                          hovertext='kuku',hoverinfo='all',hoveron='fills',name='EBBs',text='kuku2',hovertemplate = 'hover_data_0')
        fig.add_scatter(x=ebbs_shapes['x'], y=ebbs_shapes['y'], line={
                        'color': 'RoyalBlue', 'width': 0}, name='EBBs', opacity=0.3, fill='toself', hoverinfo='skip')
        if data_df_list is not None and len(data_df_list) > 0:
            symbols = dict(startpoint='green', endpoint='blue')
            for data_df in data_df_list:
                marker_color = 'black' if 'direction' not in data_df else [
                    symbols.get(t, 'grey') for t in data_df['direction']]
                hovertemplate = "  x: %{x} y: %{y}"
                i = 1
                d = data_df.columns.difference(['x', 'y'])
                for c in d:
                    hovertemplate = f"{hovertemplate}<br>  {c}: %{{customdata[{i}]}}"
                    i = i + 1
                fig.add_scatter(x=data_df['x'], y=data_df['y'], mode="markers", customdata=data_df[d].to_records(),
                                hovertemplate=hovertemplate+"<extra></extra>", legendrank=1, marker=dict(color=marker_color), name='points')
                if 'type' in data_df:
                    for i, x in data_df[data_df['type'].isin(shapes_svg_for_fig("", 0, 0, True))].iterrows():
                        shapes.extend(shapes_svg_for_fig(
                            x['type'], x['x'], x['y']))

        fig.update_layout(shapes=shapes, autosize=True,
                          coloraxis_showscale=False,
                          newshape=dict(label=dict(
                              texttemplate="x:%{dx:.0f} y:%{dy:.0f}")))

        return fig

    def shape_exp_go(self, points, matrix):
        res = []
        x = y = 0
        max_x = 0
        max_y = 0
        for a, b in list(zip(points[::2], points[1::2])):
            x, y, _ = matrix @ [float(a), float(b), 1]
            if not res:
                res.append(f'M {x},{y}')
            res.append(f'L{x},{y}')
            max_x = max(x, max_x)
            max_y = max(y, max_y)
        return f"{' '.join(res)}", max_x, max_y


def shapes_svg_for_fig(type_of_seq, x, y, get_supported_types=False):
    shapes = dict()
    shape_size_x = 30
    shape_size_y = shape_size_x*0.7
    shape_size_10_x = shape_size_x/10
    shape_size_10_y = shape_size_y/10
    xx = x-shape_size_x/2
    yy = y-shape_size_y/2
    ret = [dict(type='path',
                line_color='black',
                path=f'M {xx},{yy} H {xx+shape_size_x} V {yy+shape_size_y} H {xx} V {yy} H {xx}',
                )]
    shapes['FF Fall'] = [
        dict(type='path',
             line_color='black',
             path=f'M {xx+shape_size_10_x } {yy+shape_size_y-shape_size_10_y} H {xx+shape_size_x/2} V {yy+shape_size_10_y} H {xx+shape_size_x-shape_size_10_x }',
             ),
        dict(type='path',
             line_color='red',
             fillcolor='red',
             path=f'M {xx+shape_size_x/2-shape_size_10_x} {yy+shape_size_y/2+shape_size_10_y} H {xx+shape_size_x/2+shape_size_10_x} L {xx+shape_size_x/2} {yy+shape_size_y/2-shape_size_10_y} Z',
             ),
    ]
    shapes['FF Rise'] = [
        dict(type='path',
             line_color='black',
             path=f'M {xx+shape_size_x-shape_size_10_x } {yy+shape_size_y-shape_size_10_y} H {xx+shape_size_x/2} V {yy+shape_size_10_y} H {xx+shape_size_10_x}',
             ),
        dict(type='path',
             line_color='red',
             fillcolor='red',
             path=f'M {xx+shape_size_x/2-shape_size_10_x} {yy+shape_size_y/2-shape_size_10_y} H {xx+shape_size_x/2+shape_size_10_x} L {xx+shape_size_x/2} {yy+shape_size_y/2+shape_size_10_y} Z',
             ),
    ]
    shapes['Latch Neg'] = [
        dict(type='path',
             line_color='black',
             path=f'M {xx+shape_size_10_x } {yy+shape_size_y-shape_size_10_y} H {xx+shape_size_x/2-shape_size_10_x} V {yy+shape_size_10_y}',
             ),
        dict(type='path',
             line_color='red',
             fillcolor='red',
             path=f'M {xx+shape_size_x/2-shape_size_10_x} {yy+shape_size_10_y} H {xx+shape_size_x/2+shape_size_10_x}',
             ),
        dict(type='path',
             line_color='black',
             path=f'M {xx+shape_size_x/2+shape_size_10_x} {yy+shape_size_10_y} V {yy+shape_size_y-shape_size_10_y} H {xx+shape_size_x-shape_size_10_x}',
             ),
    ]
    shapes['Latch Pos'] = [
        dict(type='path',
             line_color='black',
             path=f'M {xx+shape_size_10_x } {yy+shape_size_10_y} H {xx+shape_size_x/2-shape_size_10_x} V {yy+shape_size_y-shape_size_10_y}',
             ),
        dict(type='path',
             line_color='red',
             fillcolor='red',
             path=f'M {xx+shape_size_x/2-shape_size_10_x} {yy+shape_size_y-shape_size_10_y} H {xx+shape_size_x/2+shape_size_10_x}',
             ),
        dict(type='path',
             line_color='black',
             path=f'M {xx+shape_size_x/2+shape_size_10_x} {yy+shape_size_y-shape_size_10_y} V {yy+shape_size_10_y} H {xx+shape_size_x-shape_size_10_x}',
             ),
    ]
    if get_supported_types:
        return set(shapes.keys())
    if type_of_seq in shapes:
        ret = ret + shapes[type_of_seq]
    return ret


def parse_data_from_server(data, log=None, parse_warning=True):
    out = {'text': [[]], 'coords': [], 'table': [],
           'cache_id': [], 'data': [], 'points': [], 'sankey': [], 'warning': [], 'error': []}
    dd = 'text'
    for d in data.split('\n'):
        tt = d.strip()
        # if dd in ['data']:
        #     d = d.strip()
        #     if d == "":
        #         continue

        if tt.startswith('-I- MODE:') or tt.startswith('-I- MODEL:') or tt.startswith('-W-'):
            dd = 'warning'
            out['warning'].append([d])
        elif parse_warning and tt.startswith('Error:') or tt.startswith('**ERROR:') or tt.startswith('\x1b[1;31m-E-'):
            dd = 'error'
            out['error'].append([d])
        elif parse_warning and tt.startswith('Warning:') or tt.startswith('**WARN:'):
            dd = 'warning'
            out['warning'].append([d])
        elif parse_warning and tt.startswith('#'):
            pass
        elif tt == 'Cache_id:':
            dd = 'cache_id'
            out['cache_id'].append([])
        elif tt == 'Text:':
            dd = 'text'
            out['text'].append([])
        elif tt == 'SankeyData:':
            dd = 'sankey'
            out['sankey'].append([])
        elif tt == 'Coordinates:':
            dd = 'coords'
            out['coords'].append([])
        elif tt == 'PointsInteress:':
            dd = 'points'
            out['points'].append([])
        elif tt == 'Table:':
            dd = 'table'
            out['table'].append([])
        elif tt == 'Data:':
            dd = 'data'
            out['data'].append([])
        else:
            out[dd][-1].append(d)
    errors = []
    warnings = []
    for e in out['error']:
        if len(e) > 0:
            errors.append('\n'.join(e))
    for w in out['warning']:
        if len(w) > 0:
            warnings.append('\n'.join(w))
    if len(errors) > 0 and log:
        log.error(errors)
    if len(warnings) > 0 and log:
        log.warning(warnings)
    return ['\n'.join(errors)], ['\n'.join(warnings)], out


def make_table(df, id, columnDefs=None, dashGridOptions=dict()):
    if not columnDefs:
        columnDefs = []
        for i in df.columns:
            d = {'field': i, 'headerName': i, 'editable': False, 'tooltipField': i,
                 "tooltipComponentParams": {"color": '#d8f0d3'}, 'headerTooltip': i, }
            if 'float' in str(df[i].dtype):
                d['filter'] = 'agNumberColumnFilter'
                d['valueFormatter'] = {
                    'function': f'params.value ? d3.format(",." + ((Math.abs(params.value) > 100)?"0":(Math.abs(params.value) < 10)?"3":"2") + "~f")(params.value) : null'
                }
            else:
                d['filter'] = True
            columnDefs.append(d)
    dashGridOptions_def = {'skipHeaderOnAutoSize': True, 'columnSize': 'autoSize', 'enableCellTextSelection': True, 'ensureDomOrder': True,
                           'pagination': True,  'paginationPageSize': 30, 'paginationPageSizeSelector': [10, 30, 50, 100],
                           'tooltipInteraction': True, 'tooltipShowDelay': 0, 'rowSelection': 'single','popupParent': {'function':'setPopupsParent()'},}
    dashGridOptions_def.update(dashGridOptions)
    ret = [
        dbc.Row(dbc.Col(
            dbc.Stack(children=[
                dbc.ButtonGroup([dbc.Button('Fit width', color='light', id=make_table_callbacks_pattern_matching(id, 'fit')),
                                 dbc.Button('Spread width', color='light', id=make_table_callbacks_pattern_matching(id, 'spread'))], size="sm",),
                dbc.Button('Download CSV', color='light', id=make_table_callbacks_pattern_matching(
                    id, 'as_csv'), size="sm", className='ms-auto'),
            ], direction="horizontal"))),
        dbc.Row(dbc.Col(dag.AgGrid(
            id=id,
            persistence=True,
            persisted_props=['columnState'],
            columnDefs=columnDefs,
            rowData=df.to_dict('records'),
            dashGridOptions=dashGridOptions_def,
            # dashGridOptions={"domLayout": "autoHeight"}
            defaultColDef={'editable': False, 'resizable': True, 'sortable': True, 'filter': True,
                           'flex': 1, 'filterParams': {'buttons': ['apply', 'clear'], 'maxNumConditions': 15}},
            dangerously_allow_code=True,)
        )),]
    return dbc.Form(children=ret)


def make_table_callbacks_pattern_matching(id, add_str=None):
    if isinstance(id, dict):
        if add_str is not None:
            return {'type': f"{id.get('type')}_{add_str}", 'index': id.get('index')}
        else:
            return {'type': id.get('type'), 'index': id.get('index')}
    if add_str is not None:
        return f"{id}_{add_str}"
    else:
        return id


def make_table_callbacks(app, id):
    if app:
        app.callback(
            dash.Output(make_table_callbacks_pattern_matching(
                id), "columnSize", allow_duplicate=True),
            dash.Output(make_table_callbacks_pattern_matching(id),
                        "columnSizeOptions", allow_duplicate=True),
            dash.Input(make_table_callbacks_pattern_matching(
                id, 'spread'), "n_clicks"),
            dash.Input(make_table_callbacks_pattern_matching(
                id, 'fit'), "n_clicks"),
            prevent_initial_call=True,
        )(update_columnSize)
        app.callback(
            dash.Output(make_table_callbacks_pattern_matching(
                id), "exportDataAsCsv", allow_duplicate=True),
            dash.Input(make_table_callbacks_pattern_matching(
                id, 'as_csv'), "n_clicks"),
            prevent_initial_call=True,
        )(export_data_as_csv)


def update_columnSize(v1, v2):
    n = dash.ctx.triggered_id.get('type') if isinstance(
        dash.ctx.triggered_id, dict) else dash.ctx.triggered_id
    if n.endswith("_fit"):  # type: ignore
        return "sizeToFit", {"skipHeader": False}
    else:
        return "autoSize", {"skipHeader": True}


def export_data_as_csv(n_clicks):
    if n_clicks:
        return True
    return False

# server_run_cmd


def get_data_from_pt_server_ohad(cmd, ohad):
    o = f'/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m {ohad} -c'
    cmd0 = '"set a [source /nfs/site/disks/ayarokh_wa/tools/sio_mow/tcl/sio_common.tcl]"'
    cmd1 = '"set b [source /nfs/site/disks/ayarokh_wa/tools/sio_mow/tcl/carpet.tcl]"'
    # o = f'/nfs/site/proj/lnl/cdgptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl -m {ohad} -c'
    # cmd0= '"set a [source /nfs/site/disks/ayarokh_wa/git/bei/sio/tcl/sio_common.tcl]"'
    r = subprocess.run([f"{o} {cmd0}"], shell=True, capture_output=True, text=True)
    r = subprocess.run([f"{o} {cmd1}"], shell=True, capture_output=True, text=True)
    result = subprocess.run(
        [f"{o} '{cmd}'"], shell=True, capture_output=True, text=True)
    p = result.stdout
    return p


def pt_server_ping(host='127.0.0.1', port=0):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.01)
            s.connect((host, port))
        return 1
    except socket.timeout:
        return 0
    except:
        return -1


def get_data_from_pt_server(cmd, host='127.0.0.1', port=0):
    fragments = ''
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((host, port))
        s.sendall(f'{cmd}\n'.encode())
        while True:
            chunk = s.recv(10000)
            if not chunk:
                break
            fragments += chunk.decode()
    return fragments


def mow_read_compare_models_report(fin):
    fields = ['port', 'new_WNS', 'ref_WNS', 'comment']
    lines = []
    with open_file(fin) as f:
        row = 0
        for line in f:
            if line.strip() == '':
                continue
            if row == 0 and line.strip().startswith('Port'):
                continue

            row += 1
            start = 0
            lline = []
            for i in range(0, len(fields)-1):
                end = line.find('|', start)
                d = line[start: end].strip()
                if d != '' and i > 0:
                    if d == '-POS':
                        d = -float('inf')
                    elif d == '':
                        d = None
                    else:
                        try:
                            d = float(d)
                        except ValueError:
                            pass
                lline.append(d)
                start = end + 1
            lline.append(line[start:].strip())
            lines.append(lline)
    df = pd.DataFrame(lines, columns=fields)
    return df


def mow_read_port_sum_report_is_ryl(file):
    with open(file[0]) as fin:
        l = fin.readline()
        return l.startswith('#1_Group')


def mow_read_port_sum_report(files):
    dfs = list()
    sep = ' '
    ryl_format = True
    for f in files:
        with open(f) as fin:
            l = fin.readline()
            if l.startswith('port') and len(l.split(',')) > 5:
                sep = ','
            if l.startswith('#1_Group'):
                ryl_format = True
                sep = ','
        if ryl_format:
            df = pd.read_csv(f, low_memory=False)
            cols = []
            for col in df.columns:
                if col.startswith('#'):
                    col = col[1:]
                if col.split("_")[0].isdigit() and len(col.split("_")) > 1:
                    col = '_'.join(col.split("_")[1:])
                cols.append(col)
            df.columns = cols
            dfs.append(df)
        elif sep == ',':
            dfs.append(pd.read_csv(f))
        elif sep == ' ':
            dfs.append(pd.read_csv(f, delim_whitespace=True))
        else:
            continue
    df = pd.concat(dfs, ignore_index=True)
    df.columns = df.columns.str.strip().str.lower()
    if 'port' in df:
        df['port'] = df['port'].replace('', np.nan)
        df.dropna(subset=['port'], inplace=True)
    return df


def create_df_table_from_string(data):
    buffer = io.StringIO('\n'.join(data))
    df = pd.read_csv(buffer)
    return df


class open_file(object):
    def __init__(self, file_name):
        self.file_name = file_name

    def __enter__(self):
        if '.gz' in pathlib.Path(self.file_name).suffixes:
            self.out = gzip.open(self.file_name, 'rt')
        else:
            self.out = open(self.file_name, 'r')
        return self.out

    def __exit__(self, *args):
        self.out.close()


def find_free_port():
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(('', 0))
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        return s.getsockname()[1]


def compress_pin(pin):
    # regex = r'(?<=\[)\d+?(?=\])|(?<=_)\d+?(?=_)|(?<=_)\d+$'
    if isinstance(pin, str):
        pattern_square_brackets = r'\[\d+\]'
        pin = re.sub(pattern_square_brackets, '[*]', pin)

        pattern_between_characters = r'(?<=_|\.)\d+(?=_|\.|$|/)'
        pin = re.sub(pattern_between_characters, r'*', pin)

        ends_pin = r'(/[do])\d+$'
        pin = re.sub(ends_pin, r"\1*", pin)
        return pin
    else:
        return ""


def compress_df_by(df, by):
    compressed_name = f'{by}_compress'
    df[compressed_name] = df[by].apply(compress_pin)
    return [df, compressed_name]
