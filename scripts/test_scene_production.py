"""Exercise rejection gates with real images; no game assets are modified."""
import copy
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from scene_production import inspect_asset, digest, check_evidence, frame_fit, compile_recipe, write
from types import SimpleNamespace


class AssetGates(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.base=Path(self.temp.name)
        Image.new("RGBA",(128,128),(100,80,60,255)).save(self.base/"tile.png")
        self.asset={"path":"tile.png","sha256":digest(self.base/"tile.png"),"size_m":[2,2],
                    "anchor_uv":[.5,.5],"view_policy":"surface","contact":"surface",
                    "representation":"surface_texture","semantic_review":"test fixture","max_projected_short_axis_px":64}
    def tearDown(self):self.temp.cleanup()
    def errors(self,asset):return inspect_asset(asset,self.base)["errors"]
    def test_surface(self):self.assertEqual(self.errors(self.asset),[])
    def test_missing_support_is_not_accepted(self):
        a=copy.deepcopy(self.asset);a["contact"]="grounded"
        self.assertIn("ground support points missing",self.errors(a))
    def test_hanging_is_not_grounded(self):
        a=copy.deepcopy(self.asset);a.update(contact="suspended",footprints_m=[[[0,0],[1,0],[1,1]]])
        self.assertIn("hanging attachment missing",self.errors(a))
        self.assertIn("suspended object cannot fake a grounded footprint",self.errors(a))
    def test_changed_art_invalidates_metadata(self):
        a=copy.deepcopy(self.asset);a["sha256"]="old"
        self.assertTrue(any("hash changed" in e for e in self.errors(a)))
    def test_near_texture_resolution(self):
        a=copy.deepcopy(self.asset);a["max_projected_short_axis_px"]=500
        self.assertTrue(any("resolution" in e for e in self.errors(a)))
    def test_zero_footprint_rejected(self):
        a=copy.deepcopy(self.asset);a.update(contact="grounded",support_points_m=[[0,0,0]],footprints_m=[[[0,0],[0,0],[0,0]]])
        self.assertIn("degenerate footprint",self.errors(a))
    def test_malformed_footprint_reports_error_not_crash(self):
        a=copy.deepcopy(self.asset);a.update(contact="grounded",support_points_m=[[0,0,0]],footprints_m=[[[0,0],[1],[1,1]]])
        self.assertIn("footprint coordinates invalid",self.errors(a))
    def test_missing_evidence_never_passes(self):
        self.assertTrue(check_evidence(self.base))
    def test_frame_rejects_tall_narrow_aperture(self):
        self.assertFalse(frame_fit(dict(image_width_px=1971,image_height_px=798,visible_height_fraction=741/798,opening_width_fraction=.6002,required_opening_m=7.6,ceiling_height_m=3.8))['uniform_scale_feasible'])
    def test_frame_accepts_wide_low_aperture(self):
        self.assertTrue(frame_fit(dict(image_width_px=2400,image_height_px=600,visible_height_fraction=.9,opening_width_fraction=.85,required_opening_m=7.6,ceiling_height_m=3.8))['uniform_scale_feasible'])
    def test_wrong_family_adapter_rejected(self):
        path=self.base/'recipe.json';write(path,{'id':'test_wrong_family','family':'forest','style':'test','adapter':'indoor','assets':[]})
        with self.assertRaisesRegex(ValueError,'Wrong family adapter'):compile_recipe(SimpleNamespace(recipe=str(path)))
    def test_empty_recipe_not_compiled(self):
        path=self.base/'recipe.json';write(path,{'id':'test_empty_recipe','family':'forest','style':'test','adapter':'godot/scripts/spaces/layouts/forest_layout.gd','assets':[]})
        with self.assertRaisesRegex(ValueError,'explicitly bind'):compile_recipe(SimpleNamespace(recipe=str(path)))


if __name__=="__main__":unittest.main()
