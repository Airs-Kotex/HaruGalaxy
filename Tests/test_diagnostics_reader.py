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

    def test_input_pipeline_orders_stages_and_keeps_block_reason(self):
        def record(sequence, event, fields):
            return json.dumps({"time":sequence,"sequence":sequence,"event":event,"fields":fields,"session":"touch-test"})+"\n"
        result=reader.summarize({"schema":1,"logs":{
            "new":record(5,"panel.blocked",{"reason":"presented_controller"}),
            "old":record(1,"overlay.hit_test",{"gatedIn":True})+
                  record(2,"input.edge_delivery",{"phase":0})+
                  record(3,"edge.touch_begin",{})+record(4,"edge.activate",{})}})
        pipeline=result["input_pipeline"]
        self.assertEqual([row["sequence"] for row in pipeline["recent_events"]],[1,2,3,4,5])
        self.assertEqual(pipeline["counts"]["panel.blocked"],1)
        self.assertNotIn("panel.open",pipeline["counts"])
        self.assertEqual(pipeline["recent_events"][-1]["fields"]["reason"],"presented_controller")
        self.assertIn("not delivered touches",pipeline["interpretation"])

    def test_input_trace_is_bounded_and_old_bundles_are_supported(self):
        rows=[json.dumps({"time":i,"sequence":i,"event":"edge.activate","fields":{}}) for i in range(100)]
        result=reader.summarize({"schema":1,"logs":{"events":"\n".join(rows)}})
        self.assertEqual(result["input_pipeline"]["counts"]["edge.activate"],100)
        self.assertEqual(len(result["input_pipeline"]["recent_events"]),80)
        self.assertEqual(result["input_pipeline"]["recent_events"][0]["sequence"],20)
        self.assertEqual(reader.summarize({"schema":1,"logs":{}})["input_pipeline"]["counts"],{})


if __name__=="__main__": unittest.main()
