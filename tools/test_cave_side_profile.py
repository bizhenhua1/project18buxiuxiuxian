"""Production boundaries for the experimental 2D enclosure compiler.

These are not visual-approval tests. They prevent lost assembly members,
accidental changes outside the experiment, asset role confusion and stretching.
Actual native visibility and terrain queries are still required.
"""
import copy
import json
from pathlib import Path
import unittest
from PIL import Image
from compile_cave_side_profile import compile_layout, qualified_source
from compile_cave_formation_groups import parent_links

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'scene-production/jobs/cave-c1-benchmark/algorithm-lab/cards-roof-coverage-03/fork.json'
LEFT='godot/assets/biomes/crystal/cards-study/shoulder-left-covered-c.png'
RIGHT='godot/assets/biomes/crystal/cards-study/shoulder-right-covered-c.png'


class SideProfileContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=json.loads(BASE.read_text(encoding='utf-8'))
        cls.original=copy.deepcopy(cls.source)
        cls.result=compile_layout(cls.source,left_asset=LEFT,right_asset=RIGHT,
            covered_height=5.2,align_covered_roof=True,coverage_shoulders=True,
            paired_backfill=True,coverage_stride=2,cover_roof_edges=True)

    def test_original_and_other_regions_are_untouched(self):
        self.assertEqual(self.source,self.original)
        def protected(spec):
            cards=spec['cards']; links=parent_links(cards)
            # Ground dressing stores owner_branch, not branch, and sits
            # 12cm before its parent. Protect complete groups by their root.
            return [c for i,c in enumerate(cards)
                    if cards[links.get(i,i)].get('branch')!=-1
                    or cards[links.get(i,i)]['z']<51]
        self.assertCountEqual(protected(self.source),protected(self.result))
        self.assertEqual(self.source['route'],self.result['route'])

    def test_retained_roofs_have_both_grounded_shoulders_and_backfill(self):
        cards=self.result['cards']
        roofs=[c for c in cards if c['role']=='outer-crown' and c.get('branch')==-1 and c['z']>=51]
        for roof in roofs:
            for role,offset in [('left',.08),('right',.08),('outer-left',-.04),('outer-right',-.04)]:
                matches=[c for c in cards if c['role']==role and c.get('branch')==-1
                         and abs(c['z']-roof['z']-offset)<1e-7]
                self.assertEqual(len(matches),1,(role,roof['z']))

    def test_full_sources_are_not_warped_or_mirrored(self):
        dimensions={}
        for c in self.result['cards']:
            if not c.get('study_profile'):continue
            if c['asset'] not in dimensions:
                with Image.open(ROOT/c['asset']) as image:dimensions[c['asset']]=image.size
            w,h=dimensions[c['asset']]
            self.assertAlmostEqual(c['width']/c['height'],w/h)
            self.assertEqual(c['uv'],[0,0,1,1])
            self.assertEqual(c.get('yaw',0),0)
            self.assertFalse(c.get('flip',False))

    def test_wrong_side_source_rejected(self):
        with self.assertRaisesRegex(ValueError,'measured role'):
            qualified_source(RIGHT,'left_shoulder_continuation')

    def test_incomplete_assembly_rejected(self):
        with self.assertRaisesRegex(ValueError,'two authored'):
            compile_layout(self.source,left_asset=LEFT,coverage_shoulders=True)


if __name__=='__main__':unittest.main()
