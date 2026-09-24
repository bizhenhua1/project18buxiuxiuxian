"""Counterexamples for empty groups and lost child/placement provenance."""
import json
from pathlib import Path
import unittest
from compile_cave_formation_groups import compile_layout, parent_links

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scene-production/jobs/cave-c1-benchmark/algorithm-lab/cards-quiet-fill-02/fork.json'


class FormationContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(SOURCE.read_text(encoding='utf-8'))
        cls.thinned = compile_layout(cls.source, 8)
        cls.complete = compile_layout(cls.source, 8, complete=True)

    def test_already_sparse_input_must_not_silently_empty_authored_groups(self):
        # This actual source left several 8m intervals empty under double
        # filtering. The new placement grammar must supply its declared pair.
        self.assertGreater(self.thinned['formation_groups_trial']['empty_groups'], 0)
        groups = self.complete['formation_groups_trial']['groups']
        self.assertTrue(groups)
        for group in groups:
            self.assertCountEqual([c['role'] for c in group['authored']], group['expressive_roles'])

    def test_asset_selection_does_not_advance_macro_layout_randomness(self):
        def skeleton(spec):
            return [(g['id'], g['interval_m'], g['expressive_roles'])
                    for g in spec['formation_groups_trial']['groups']]
        self.assertEqual(skeleton(self.thinned), skeleton(self.complete))

    def test_every_retained_or_new_child_has_a_retained_parent(self):
        cards = self.complete['cards']
        identities = {c['study_id']: c for c in cards}
        self.assertEqual(len(identities), len(cards))
        linked = 0
        for card in cards:
            if card['role'] == 'ground-transition' or card.get('support_kind') == 'ceiling_attachment':
                self.assertIn(card['study_parent_id'], identities)
                linked += 1
        self.assertGreater(linked, 0)

    def test_continuous_fill_and_fork_seams_are_not_repositioned(self):
        roles = {'outer-left', 'outer-right', 'outer-crown', 'medial-rock'}
        for card in self.complete['cards']:
            if card['role'] not in roles:
                continue
            index = int(card['study_id'].split(':')[-1])
            original = self.source['cards'][index]
            for key, value in original.items():
                self.assertEqual(card[key], value)

    def test_missing_role_is_reported_instead_of_an_empty_zone(self):
        source = json.loads(json.dumps(self.source))
        removed = {i for i, c in enumerate(source['cards']) if c['role'] == 'right' and c['z'] >= 51}
        removed.update(i for i, parent in parent_links(source['cards']).items() if parent in removed)
        source['cards'] = [c for i, c in enumerate(source['cards']) if i not in removed]
        with self.assertRaisesRegex(ValueError, 'No qualified template.*right'):
            compile_layout(source, 8, complete=True)


if __name__ == '__main__':
    unittest.main()
