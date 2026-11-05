import pathlib
import plistlib
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
LAYOUT = ROOT / 'Vendor/Colemak DH.bundle'


def load_layout(path):
    # Apple's keyboard-layout XML uses numeric control-character references disallowed by generic XML 1.0 parsers.
    xml = path.read_text()
    xml = re.sub(r'&#x(?:0{0,3}[0-8BCEF]|0{0,2}1[0-9A-F]);', '?', xml, flags=re.I)
    return ET.fromstring(xml)


class LayoutTests(unittest.TestCase):
    def test_ansi_is_colemak_dh_not_standard_colemak(self):
        root = load_layout(LAYOUT / 'Contents/Resources/Colemak DH ANSI.keylayout')
        actions = {
            action.get('id'): action.find('./when[@state="none"]').get('output')
            for action in root.findall('./actions/action')
            if action.find('./when[@state="none"]') is not None
        }
        keys = root.findall('./keyMapSet/keyMap[@index="0"]/key')
        result = {
            int(key.get('code')): key.get('output') or actions[key.get('action')]
            for key in keys if key.get('output') or key.get('action') in actions
        }
        # Physical ANSI QWERTY key codes, in row order.
        rows = ([12, 13, 14, 15, 17, 16, 32, 34, 31, 35],
                [0, 1, 2, 3, 5, 4, 38, 40, 37, 41],
                [6, 7, 8, 9, 11, 45, 46, 43, 47, 44])
        self.assertEqual([''.join(result[code] for code in row) for row in rows],
                         ['qwfpbjluy;', 'arstgmneio', 'xcdvzkh,./'])
        self.assertTrue(root.find('./keyMapSet/keyMap[@index="1"]') is not None)  # Shift
        self.assertTrue(root.find('./keyMapSet/keyMap[@index="3"]') is not None)  # Option

    def test_app_packages_official_bundle(self):
        with (LAYOUT / 'Contents/Info.plist').open('rb') as file:
            self.assertEqual(plistlib.load(file)['CFBundleIdentifier'],
                             'io.github.colemakmods.keyboardlayout.colemakdh')
        self.assertEqual(len(list((LAYOUT / 'Contents/Resources').glob('*.keylayout'))), 7)
        built = ROOT / '.build/Colemak-DH-Installer.app/Contents/Resources/Colemak DH.bundle'
        if built.exists():
            self.assertEqual((built / 'Contents/Resources/Colemak DH ANSI.keylayout').read_bytes(),
                             (LAYOUT / 'Contents/Resources/Colemak DH ANSI.keylayout').read_bytes())


if __name__ == '__main__':
    unittest.main()
