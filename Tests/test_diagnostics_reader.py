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

    def test_search_trace_keeps_launch_acceptance_separate_from_visible_keyboard(self):
        events=[
            ("search.handoff_begin",{}),
            ("overlay.search_input",{"suspended":True}),
            ("search.application_open",{"accepted":True}),
            ("search.handoff_timeout",{"mainSceneState":2}),
            ("overlay.search_input",{"suspended":False})]
        text="\n".join(json.dumps({"time":i,"sequence":i,"event":e,"fields":f}) for i,(e,f) in enumerate(events))
        result=reader.summarize({"schema":1,"logs":{"events":text}})["search_pipeline"]
        self.assertEqual(result["counts"]["overlay.search_input"],2)
        self.assertNotIn("search.keyboard_shown",result["counts"])
        self.assertIn("not foreground visibility",result["interpretation"])
        self.assertEqual(result["recent_events"][-1]["fields"],{"suspended":False})

    def test_keyboard_pipeline_distinguishes_registration_request_and_visibility(self):
        names=["keyboard.environment_registered","keyboard.environment_applied",
               "keyboard.focus_requested","keyboard.focus_completed","keyboard.focus_unavailable"]
        records="\n".join(json.dumps({"time":i,"sequence":i,"event":event,"fields":{}}) for i,event in enumerate(names))
        result=reader.summarize({"schema":1,"logs":{"events":records}})["keyboard_pipeline"]
        self.assertEqual(result["counts"]["keyboard.focus_requested"],1)
        self.assertNotIn("keyboard.visibility",result["counts"])
        self.assertEqual([row["event"] for row in result["recent_events"]],names)
        self.assertIn("do not prove a focus grant",result["interpretation"])

    def test_guest_request_and_preparation_do_not_imply_keyboard_visible(self):
        events=[("keyboard.presentation_prepared",{"windowReturned":True}),
                ("keyboard.guest_input_state",{"systemInputActive":True}),
                ("keyboard.focus_observed",{"after":1.0,"state":{"visible":False}})]
        text="\n".join(json.dumps({"time":i,"sequence":i,"event":event,"fields":fields}) for i,(event,fields) in enumerate(events))
        data=reader.summarize({"schema":1,"logs":{"events":text}})["keyboard_pipeline"]
        self.assertNotIn("keyboard.visibility",data["counts"])
        self.assertFalse(data["recent_events"][-1]["fields"]["state"]["visible"])
        self.assertIn("guest-reported request",data["interpretation"])

    def test_input_board_retains_stages_across_rotated_logs_without_inventing_success(self):
        def row(i, event, fields):
            return json.dumps({"time":i,"sequence":i,"event":event,"fields":fields})+"\n"
        result=reader.summarize({"schema":1,"logs":{
            "new":row(3,"input_board.finished",{"copied":True})+
                  row(4,"input_board.original_open",{"accepted":False}),
            "old":row(1,"input_board.focus",{"accepted":True})+
                  row(2,"input_board.keyboard",{"overlap":0})}})
        board=result["input_board_pipeline"]
        self.assertEqual([r["sequence"] for r in board["recent_events"]],[1,2,3,4])
        self.assertEqual(board["recent_events"][1]["fields"]["overlap"],0)
        self.assertFalse(board["recent_events"][-1]["fields"]["accepted"])
        self.assertEqual(result["keyboard_pipeline"]["counts"],{})
        self.assertIn("not insertion into the guest",board["interpretation"])
        self.assertEqual(reader.summarize({"schema":1,"logs":{}})["input_board_pipeline"]["counts"],{})

    def test_native_release_and_launch_are_not_rendering_evidence(self):
        events=[("native_handoff.deactivating",{}),
                ("native_handoff.deactivated",{}),
                ("native_handoff.released",{"localReleaseConfirmed":True}),
                ("native_handoff.open_requested",{"accepted":False})]
        text="\n".join(json.dumps({"time":i,"sequence":i,"event":event,"fields":fields}) for i,(event,fields) in enumerate(events))
        data=reader.summarize({"schema":1,"logs":{"events":text}})["native_handoff_pipeline"]
        self.assertEqual(len(data["recent_events"]),4)
        self.assertFalse(data["recent_events"][-1]["fields"]["accepted"])
        self.assertIn("not that the ordinary app rendered",data["interpretation"])
        self.assertEqual(reader.summarize({"schema":1,"logs":{}})["native_handoff_pipeline"]["counts"],{})

    def test_keyboard_capture_keeps_unknown_and_bounded_observations(self):
        records=[]
        for i in range(40):
            fields={"context":{"capture":1,"sample":i},"focus":{"visible":"unavailable"},
                    "guests":[{"deliveredTouchStarts":0,"session":{"systemInputActive":True}}]}
            records.append(json.dumps({"time":i,"sequence":i,"event":"keyboard.diagnostic_sample","fields":fields}))
        result=reader.summarize({"schema":1,"logs":{"events":"\n".join(records)}})["keyboard_capture"]
        self.assertEqual(result["counts"]["keyboard.diagnostic_sample"],40)
        self.assertEqual(len(result["recent_events"]),24)
        self.assertEqual(result["recent_events"][0]["sequence"],16)
        self.assertEqual(result["recent_events"][-1]["fields"]["focus"]["visible"],"unavailable")
        self.assertIn("zero is not proof of no touch",result["interpretation"])
        self.assertEqual(reader.summarize({"schema":1,"logs":{}})["keyboard_capture"]["counts"],{})

    def test_bottom_probes_do_not_imply_delivered_guest_touches(self):
        samples=[{"time":i,"sequence":i,"session":"sample-session","event":"keyboard.diagnostic_sample",
                  "fields":{"guests":[{"bundle":"example.app","railOverlapsContent":False,
                      "bottomHitProbes":[{"region":"guest_surface","fromBottom":12,"xFraction":0.5}]}]}}
                 for i in range(30)]
        data=reader.summarize({"schema":1,"logs":{"events":"\n".join(json.dumps(r) for r in samples)}})["window_touch_pipeline"]
        self.assertEqual(data["counts"],{})
        self.assertEqual(len(data["bottom_samples"]),24)
        self.assertEqual(data["bottom_samples"][0]["sequence"],6)
        self.assertFalse(data["bottom_samples"][-1]["railOverlapsContent"])
        self.assertIn("synthetic host-window queries",data["interpretation"])
        self.assertEqual(reader.summarize({"schema":1,"logs":{}})["window_touch_pipeline"]["bottom_samples"],[])


if __name__=="__main__": unittest.main()
