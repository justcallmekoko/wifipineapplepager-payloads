import importlib.util, pathlib, struct, unittest

PATH=pathlib.Path(__file__).with_name("c5_pager_node.py")
spec=importlib.util.spec_from_file_location("node",PATH); node=importlib.util.module_from_spec(spec); spec.loader.exec_module(node)

class PayloadTests(unittest.TestCase):
    def test_payload_exposes_mmc_python_packages(self):
        payload=PATH.with_name("payload.sh").read_text()
        self.assertIn("PYTHON_MMCLIB",payload)
        self.assertLess(payload.index("export PYTHONPATH"), payload.index("c5_pager_node.py"))

class ProtocolTests(unittest.TestCase):
    def test_text_message_matches_c5_struct(self):
        msg=node.text_message(node.TEXT,7,b"hello")
        self.assertEqual(len(msg),212)
        self.assertEqual(node.parse_text_message(msg),(node.TEXT,7,b"hello"))
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
