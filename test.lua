local ffi = require('ffi')
local io = require('io')

local h264bitstream = require('h264bitstream')

local stream = h264bitstream.new()
assert(stream ~= nil)
stream[0].nal[0].nal_ref_idc = h264bitstream.NAL_REF_IDC_PRIORITY_HIGHEST
stream[0].sps[0].profile_idc = h264bitstream.H264_PROFILE_BASELINE
stream[0].sps[0].chroma_format_idc = 1 -- 4:2:0
stream[0].sps[0].level_idc = 10
stream[0].sps[0].num_ref_frames = 0
stream[0].sps[0].frame_mbs_only_flag = 1
local width, height = 128, 96 -- SQCIF
stream[0].sps[0].pic_width_in_mbs_minus1 = width / 16 - 1
stream[0].sps[0].pic_height_in_map_units_minus1 = height / 16 - 1

local buffer = ffi.new('uint8_t[1024*1024]')
local n

stream[0].nal[0].nal_unit_type = h264bitstream.NAL_UNIT_TYPE_SPS
n = h264bitstream.write_nal_unit(stream, buffer, ffi.sizeof(buffer))
assert(n > 0)
assert(n < ffi.sizeof(buffer))
io.write('SPS: ')
for i = 0, n - 1 do
    io.write(string.format('%02x ', buffer[i]))
end
io.write('\n')

stream[0].nal[0].nal_unit_type = h264bitstream.NAL_UNIT_TYPE_PPS
n = h264bitstream.write_nal_unit(stream, buffer, ffi.sizeof(buffer))
assert(n > 0)
assert(n < ffi.sizeof(buffer))
io.write('PPS: ')
for i = 0, n - 1 do
    io.write(string.format('%02x ', buffer[i]))
end
io.write('\n')
