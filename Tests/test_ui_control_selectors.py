from pathlib import Path
import importlib.util
import unittest

check_path = Path(__file__).resolve().parents[1] / "scripts/check_ui_control_selectors.py"
spec = importlib.util.spec_from_file_location("selector_check", check_path)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class UIControlSelectorTests(unittest.TestCase):
    def test_edge_handle_overrides_uicontrol_tracking_selectors(self):
        source = (Path(__file__).resolve().parents[1] / "Sources/UI/MWEdgeHandle.m").read_text()
        expected = {
            "beginTrackingWithTouch:withEvent:": r"-\s*\(BOOL\)\s*beginTrackingWithTouch:\s*\(UITouch \*\)touch\s+withEvent:",
            "continueTrackingWithTouch:withEvent:": r"-\s*\(BOOL\)\s*continueTrackingWithTouch:\s*\(UITouch \*\)touch\s+withEvent:",
            "endTrackingWithTouch:withEvent:": r"-\s*\(void\)\s*endTrackingWithTouch:\s*\(UITouch \*\)touch\s+withEvent:",
            "cancelTrackingWithEvent:": r"-\s*\(void\)\s*cancelTrackingWithEvent:\s*\(UIEvent \*\)event",
        }
        for selector, pattern in expected.items():
            self.assertRegex(source, pattern, selector)
        self.assertNotRegex(source, r"-\s*\(BOOL\)\s*beginTracking:\s*\(UITouch \*\)")
        self.assertNotRegex(source, r"-\s*\(BOOL\)\s*continueTracking:\s*\(UITouch \*\)")
        self.assertNotRegex(source, r"-\s*\(void\)\s*endTracking:\s*\(UITouch \*\)")

    def test_header_or_message_reference_cannot_count_as_implementation(self):
        ast = """Dumping MWEdgeHandle:
ObjCInterfaceDecl 0x1 <file.h:1:1> MWEdgeHandle
|-ObjCMethodDecl 0x2 <line:2> - beginTrackingWithTouch:withEvent: 'BOOL'

Dumping MWEdgeHandle:
ObjCImplementationDecl 0x3 <file.m:1:1> MWEdgeHandle
|-ObjCMethodDecl 0x4 <line:2> - helper 'void'
| `-CompoundStmt 0x5
|   `-ObjCMessageExpr 0x6 selector=beginTrackingWithTouch:withEvent:
"""
        methods = checker.direct_methods(ast, "ObjCImplementationDecl", "MWEdgeHandle")
        self.assertEqual(methods, {"helper": "void"})
        with self.assertRaisesRegex(ValueError, "Missing ObjCImplementationDecl"):
            checker.direct_methods(ast.split("Dumping MWEdgeHandle:", 2)[1],
                                   "ObjCImplementationDecl", "MWEdgeHandle")

    def test_absent_callback_wrong_selector_and_wrong_type_are_rejected(self):
        expected = dict(zip(checker.REQUIRED, ("BOOL", "BOOL", "void", "void")))
        checker.check_contract(expected, expected)
        missing = dict(expected)
        missing.pop(checker.REQUIRED[0])
        with self.assertRaisesRegex(ValueError, "missing=.*beginTrackingWithTouch"):
            checker.check_contract(missing, expected)
        stale = dict(expected, **{checker.FORBIDDEN[0]: "BOOL"})
        with self.assertRaisesRegex(ValueError, "stale=.*beginTracking:"):
            checker.check_contract(stale, expected)
        mismatch = dict(expected, **{checker.REQUIRED[0]: "void"})
        with self.assertRaisesRegex(ValueError, "type_mismatch=.*beginTrackingWithTouch"):
            checker.check_contract(mismatch, expected)

    def test_end_and_cancel_require_super_in_their_own_implementation(self):
        ast = """Dumping MWEdgeHandle:
ObjCImplementationDecl 0x1 <file.m:1:1> MWEdgeHandle
|-ObjCMethodDecl 0x2 <line:2> - endTrackingWithTouch:withEvent: 'void'
| `-CompoundStmt 0x3
|   `-ObjCMessageExpr 0x4 selector=endTrackingWithTouch:withEvent: super (instance)
`-ObjCMethodDecl 0x5 <line:3> - cancelTrackingWithEvent: 'void'
  `-CompoundStmt 0x6
    `-ObjCMessageExpr 0x7 selector=cancelTrackingWithEvent: super (instance)
"""
        checker.check_super_cleanup(ast)
        with self.assertRaisesRegex(ValueError, "missing super call in endTracking"):
            checker.check_super_cleanup(ast.replace("selector=endTrackingWithTouch:withEvent: super (instance)",
                                                   "selector=endTrackingWithTouch:withEvent:"))
        with self.assertRaisesRegex(ValueError, "missing super call in cancelTracking"):
            checker.check_super_cleanup(ast.replace("selector=cancelTrackingWithEvent: super (instance)", "selector=helper"))
