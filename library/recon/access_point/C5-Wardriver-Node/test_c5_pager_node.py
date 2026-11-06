import importlib.util, pathlib, struct, unittest

PATH=pathlib.Path(__file__).with_name("c5_pager_node.py")
spec=importlib.util.spec_from_file_location("node",PATH); node=importlib.util.module_from_spec(spec); spec.loader.exec_module(node)

class PayloadTests(unittest.TestCase):
    def test_payload_exposes_mmc_python_packages(self):
        payload=PATH.with_name("payload.sh").read_text()
        self.assertIn("PYTHON_MMCLIB",payload)
        self.assertLess(payload.index("export PYTHONPATH"), payload.index('python3 "$DIR/c5_pager_node.py"'))

class ProtocolTests(unittest.TestCase):
    def test_text_message_matches_c5_struct(self):
        msg=node.text_message(node.TEXT,7,b"hello")
        self.assertEqual(len(msg),212)
        self.assertEqual(node.parse_text_message(msg),(node.TEXT,7,b"hello"))
    def test_record_ack_round_trip(self):
        msg=node.text_message(node.RECORD_ACK,19,b"W6,5975")
        self.assertEqual(node.parse_text_message(msg),(node.RECORD_ACK,19,b"W6,5975"))
    def test_ack_client_requires_matching_detail_and_bounds_drain(self):
        source=PATH.read_text()
        self.assertIn("parsed[2]==expected_ack",source)
        self.assertIn("drain_deadline=time.monotonic()+.5",source)
        self.assertIn("count<3",source)
        self.assertIn("os.urandom(4)",source)
        self.assertIn('add_argument("--core",required=True)',source)
        self.assertIn("src==wanted",source)
    def test_payload_uses_portable_core_mac_parser(self):
        payload=PATH.with_name("payload.sh").read_text()
        self.assertIn("open(sys.argv[1]).read().strip()",payload)
        self.assertNotIn("tr -d '[:space:]'",payload)
        self.assertIn("[0-9A-Fa-f]",payload)
        self.assertIn("LAUNCH_DIR=",payload)
        self.assertIn("/root/payloads/user/reconnaissance/c5_wardriver_node/c5_pager_node.py",payload)
        self.assertIn("/mmc/root/payloads/user/reconnaissance/c5_wardriver_node/c5_pager_node.py",payload)
    def test_6ghz_beacon_record(self):
        present=(1<<1)|(1<<3)|(1<<5)
        rt=struct.pack("<BBHIBxHHb",0,0,15,present,0,5975,0,-42)
        mac=bytes.fromhex("aabbccddeeff")
        hdr=struct.pack("<HH6s6s6sH",0x80,0,b"\xff"*6,mac,mac,0)
        fixed=b"\0"*8+struct.pack("<HH",100,0x401)
        ies=b"\x00\x04Test"
        self.assertEqual(node.beacon_record(rt+hdr+fixed+ies),(mac,5,-42,"[OPEN]",b"Test"))
    def test_non_6ghz_frame_is_rejected(self):
        present=(1<<1)|(1<<3)|(1<<5)
        rt=struct.pack("<BBHIBxHHb",0,0,15,present,0,2412,0,-42)
        self.assertIsNone(node.beacon_record(rt+b"\0"*64))

if __name__=="__main__": unittest.main()
