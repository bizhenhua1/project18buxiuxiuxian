"""Geometric counterexamples, independent of native screenshot acceptance."""
import unittest
import numpy as np
from audit_cave_event_visibility import body_rays
from cave_art_cards import raycast
from compile_cave_event_cards import profile


class EventLayoutTests(unittest.TestCase):
    def setUp(self):
        self.body=dict(position_m=[0.,0.,10.],width_m=2.,height_m=2.)
        self.camera=[0.,1.,0.]
        self.mask=np.full((8,8),255,dtype=np.uint8)

    def blocked(self,cards,mask=None):
        dx,dy,opaque,depth=body_rays(self.body,self.camera,self.mask if mask is None else mask,samples=40)
        distance,owner=raycast(cards,self.camera,dx.shape,{'solid':self.mask},ray_slopes=(dx,dy))
        return int((opaque & (owner>=0) & (distance<depth-.025)).sum())

    def card(self,x=0.,z=5.,width=1.):
        return dict(asset='solid',x=x,y=0.,z=z,width=width,height=2.,uv=[0,0,1,1])

    def test_between_camera_and_enemy_blocks_even_without_body_intersection(self):
        self.assertEqual(self.blocked([self.card()]),1600)

    def test_art_behind_enemy_does_not_block(self):
        self.assertEqual(self.blocked([self.card(z=12.,width=4.)]),0)

    def test_one_side_has_half_occlusion(self):
        self.assertEqual(self.blocked([self.card(x=-.25,width=.5)]),800)

    def test_transparent_body_canvas_not_reserved_as_body(self):
        mask=self.mask.copy();mask[:,:4]=0
        self.assertEqual(self.blocked([self.card(x=-.25,width=.5)],mask),0)

    def test_camera_plane_or_behind_is_rejected(self):
        self.body['position_m'][2]=0
        with self.assertRaises(ValueError):body_rays(self.body,self.camera,self.mask)

    def test_reserve_keeps_peaks_and_has_finite_extent(self):
        needs=[(40.,1.5),(44.,.8)]
        self.assertGreaterEqual(profile(40.,needs,.4),1.5)
        self.assertGreaterEqual(profile(44.,needs,.4),.8)
        self.assertEqual(profile(25.,needs,.4),0)
        self.assertEqual(profile(60.,needs,.4),0)


if __name__=='__main__':unittest.main()
