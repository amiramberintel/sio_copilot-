import logging
import modules.sio_mow_common as sio_mow_common
from modules import svgs

logger = logging.getLogger(__name__)
class pt_session:
    ''' Class to save all initial data from PT includes SVG of floorplan'''
    __initial_data: dict | None
    __server: str | dict
    __svg_key: str | None
    __problems: list
    __in_use: bool

    def __init__(self, server: str) -> None:
        self.__in_use = True
        self.__initial_data = None
        self.__svg_key = None
        if ':' in server:
            host, port = server.split(':')
            self.__server = {'address': host, 'port': int(port)}
        else:
            self.__server = server
        try:
            init = sio_mow_common.init_data(self.__server, logger)
            self.__problems = init.messages
            self.__initial_data = init.init_data
        except:
            self.__problems = [
                dict(title="Error!", message='Cannot get server', color='red')]
            self.__in_use = False
        self.__svg_get()

    def __svg_get(self):
        if self.__initial_data:
            self.__svg_key = svgs.svgs.add(
                self.__initial_data['block'],
                self.__initial_data['TD_COLLATERAL_TAG'],
                self.__initial_data['PROJ_ARCHIVE'] + "/arc",
                self.__initial_data.get('lo_locations', None),
            )

    @property
    def in_use(self) -> bool: return self.__in_use

    @property
    def problems(self) -> list: return self.__problems

    @property
    def fig(self):
        return svgs.svgs.get_fig_by_key(self.__svg_key) if self.__svg_key else None

    def fig_points(self, lines=dict(), points=None):
        return svgs.svgs.get_fig_by_key(self.__svg_key, lines, points) if self.__svg_key else None

    @property
    def block(self):
        if self.__initial_data:
            return self.__initial_data.get('block', None)
        return None

    @property
    def init_data(self):
        if self.__initial_data:
            return self.__initial_data
        return None

    @property
    def name(self):
        if self.__initial_data:
            return self.__initial_data.get('name', None)
        return None

    @property
    def product_name(self):
        if self.__initial_data:
            return self.__initial_data.get('PRODUCT_NAME', None)
        return None

    def __get_pt_data(self, cmd):
        data = None
        
        if isinstance(self.__server, dict):
            data = sio_mow_common.get_data_from_pt_server(
                cmd, host=self.__server['address'], port=self.__server['port'])
        else:
            data = sio_mow_common.get_data_from_pt_server_ohad(
                f'server_run_cmd_ohad "{cmd}"', self.__server)

        return data

    def run_cmd(self, cmd, parse_warning=True):
        errors = []
        warnings = []
        data = None
        try:
            data = self.__get_pt_data(cmd)
            errors, warnings, data = sio_mow_common.parse_data_from_server(
                data, logger, parse_warning=parse_warning)
        except Exception as e:
            logger.error(f"Error getting data from server: {e}")
            data = dict(error=[[f"Error getting data from server: {e}"]])
        return data

    def run_free_command(self, command):
        data = self.run_cmd(f'free_command {command}', parse_warning=False)
        return data
