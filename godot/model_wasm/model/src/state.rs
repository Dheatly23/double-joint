use core::ptr::null;

use glam::f32::*;

pub(crate) struct State {
    vertex: Vec<Vec3>,
    normal: Vec<Vec3>,
    tangent: Vec<Vec4>,
    uv: Vec<Vec2>,
    index: Vec<u32>,
    vertex_data: Vec<u8>,
    attr_data: Vec<u8>,
}

#[repr(C)]
pub struct ExportState {
    pub vertex_cnt_l1: usize,
    pub vertex_ptr_l1: *const Vec3,
    pub normal_ptr_l1: *const Vec3,
    pub tangent_ptr_l1: *const Vec4,
    pub uv_ptr_l1: *const Vec2,
    pub index_cnt_l1: usize,
    pub index_ptr_l1: *const u32,
    pub vertex_data_len_l1: usize,
    pub vertex_data_ptr_l1: *const u8,
    pub attr_data_len_l1: usize,
    pub attr_data_ptr_l1: *const u8,

    pub vertex_cnt_l2: usize,
    pub vertex_ptr_l2: *const Vec3,
    pub normal_ptr_l2: *const Vec3,
    pub tangent_ptr_l2: *const Vec4,
    pub uv_ptr_l2: *const Vec2,
    pub index_cnt_l2: usize,
    pub index_ptr_l2: *const u32,
    pub vertex_data_len_l2: usize,
    pub vertex_data_ptr_l2: *const u8,
    pub attr_data_len_l2: usize,
    pub attr_data_ptr_l2: *const u8,

    pub angles: Angles,
}

#[derive(Debug, Clone, Copy, PartialEq)]
#[repr(C)]
pub struct Angles {
    pub draw_layer2: u8,
    pub layer2_off: f32,

    pub head_basis: Mat3,

    pub larm_basis: Mat3,
    pub lelbow_basis: Mat3,

    pub rarm_basis: Mat3,
    pub relbow_basis: Mat3,

    pub lleg_basis: Mat3,
    pub lknee_basis: Mat3,

    pub rleg_basis: Mat3,
    pub rknee_basis: Mat3,
}

impl State {
    pub(crate) const fn new() -> Self {
        Self {
            vertex: Vec::new(),
            normal: Vec::new(),
            tangent: Vec::new(),
            uv: Vec::new(),
            index: Vec::new(),
            vertex_data: Vec::new(),
            attr_data: Vec::new(),
        }
    }

    pub(crate) fn clear(&mut self) {
        self.vertex.clear();
        self.normal.clear();
        self.tangent.clear();
        self.uv.clear();
        self.index.clear();
        self.vertex_data.clear();
        self.attr_data.clear();
    }

    #[inline(always)]
    pub(crate) fn len(&self) -> usize {
        self.vertex.len()
    }

    pub(crate) fn add_vertices<I>(&mut self, it: I)
    where
        I: IntoIterator<Item = (Vec3, Vec3, Vec4, Vec2)>,
    {
        for (v, n, t, uv) in it {
            self.vertex.push(v);
            self.normal.push(n);
            self.tangent.push(t);
            self.uv.push(uv);
        }
    }

    pub(crate) fn add_indices<I>(&mut self, it: I)
    where
        I: IntoIterator<Item = u32>,
    {
        self.index.extend(it);
    }

    pub(crate) fn set_vertex_data<'a, F, I>(&'a mut self, f: F)
    where
        F: FnOnce(&'a [Vec3], &'a [Vec3], &'a [Vec4]) -> I,
        I: 'a + IntoIterator<Item = u8>,
    {
        self.vertex_data.clear();
        self.vertex_data
            .extend(f(&self.vertex, &self.normal, &self.tangent));
    }

    pub(crate) fn set_attr_data<'a, F, I>(&'a mut self, f: F)
    where
        F: FnOnce(&'a [Vec2]) -> I,
        I: 'a + IntoIterator<Item = u8>,
    {
        self.attr_data.clear();
        self.attr_data.extend(f(&self.uv));
    }
}

impl ExportState {
    pub(crate) const fn new() -> Self {
        Self {
            vertex_cnt_l1: 0,
            vertex_ptr_l1: null(),
            normal_ptr_l1: null(),
            tangent_ptr_l1: null(),
            uv_ptr_l1: null(),
            index_cnt_l1: 0,
            index_ptr_l1: null(),
            vertex_data_len_l1: 0,
            vertex_data_ptr_l1: null(),
            attr_data_len_l1: 0,
            attr_data_ptr_l1: null(),

            vertex_cnt_l2: 0,
            vertex_ptr_l2: null(),
            normal_ptr_l2: null(),
            tangent_ptr_l2: null(),
            uv_ptr_l2: null(),
            index_cnt_l2: 0,
            index_ptr_l2: null(),
            vertex_data_len_l2: 0,
            vertex_data_ptr_l2: null(),
            attr_data_len_l2: 0,
            attr_data_ptr_l2: null(),

            angles: Angles {
                draw_layer2: 0,
                layer2_off: 0.0,

                head_basis: Mat3::ZERO,

                larm_basis: Mat3::ZERO,
                lelbow_basis: Mat3::ZERO,

                rarm_basis: Mat3::ZERO,
                relbow_basis: Mat3::ZERO,

                lleg_basis: Mat3::ZERO,
                lknee_basis: Mat3::ZERO,

                rleg_basis: Mat3::ZERO,
                rknee_basis: Mat3::ZERO,
            },
        }
    }

    pub(crate) fn import(&mut self, layer1: &State, layer2: &State) {
        self.vertex_cnt_l1 = layer1.vertex.len();
        self.vertex_ptr_l1 = layer1.vertex.as_ptr();
        self.normal_ptr_l1 = layer1.normal.as_ptr();
        self.tangent_ptr_l1 = layer1.tangent.as_ptr();
        self.uv_ptr_l1 = layer1.uv.as_ptr();
        self.index_cnt_l1 = layer1.index.len();
        self.index_ptr_l1 = layer1.index.as_ptr();
        self.vertex_data_len_l1 = layer1.vertex_data.len();
        self.vertex_data_ptr_l1 = layer1.vertex_data.as_ptr();
        self.attr_data_len_l1 = layer1.attr_data.len();
        self.attr_data_ptr_l1 = layer1.attr_data.as_ptr();

        self.vertex_cnt_l2 = layer2.vertex.len();
        self.vertex_ptr_l2 = layer2.vertex.as_ptr();
        self.normal_ptr_l2 = layer2.normal.as_ptr();
        self.tangent_ptr_l2 = layer2.tangent.as_ptr();
        self.uv_ptr_l2 = layer2.uv.as_ptr();
        self.index_cnt_l2 = layer2.index.len();
        self.index_ptr_l2 = layer2.index.as_ptr();
        self.vertex_data_len_l2 = layer2.vertex_data.len();
        self.vertex_data_ptr_l2 = layer2.vertex_data.as_ptr();
        self.attr_data_len_l2 = layer2.attr_data.len();
        self.attr_data_ptr_l2 = layer2.attr_data.as_ptr();
    }
}
