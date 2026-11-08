import importlib.util
import json
from pathlib import Path
import unittest

source=Path(__file__).resolve().parents[1]/"scripts/inspect_diagnostics.py"
spec=importlib.util.spec_from_file_location("diagnostic_reader",source)
reader=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class DiagnosticsReaderTests(unittest.TestCase):
    def test_rotated_logs_order_and_incomplete_record(self):
        def record(sequence,event):
            return json.dumps({"time":sequence,"sequence":sequence,"event":event,"fields":{},"session":"test"})+"\n"
        result=reader.summarize({"schema":1,"environment":{"model":"test"},"dropped":1,"logs":{
            "events-0.jsonl":record(20,"user.problem_marker")+'{"partial":',
            "events-1.jsonl":record(10,"heartbeat.gap")}})
        self.assertEqual(result["events"],2)
        self.assertEqual([event["sequence"] for event in result["important_events"]],[10,20])
        self.assertEqual(result["malformed_lines"],["events-0.jsonl:2"])
        self.assertEqual(result["dropped"],1)

    def test_invalid_schema_rejected(self):
        with self.assertRaises(ValueError): reader.summarize({"schema":0,"logs":{}})

    def test_non_text_entry_does_not_crash(self):
        result=reader.summarize({"schema":1,"logs":{"bad":[]}})
        self.assertEqual(result["events"],0)
        self.assertEqual(len(result["malformed_lines"]),1)


if __name__=="__main__": unittest.main()
