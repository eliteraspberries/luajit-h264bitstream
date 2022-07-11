local h264bitstream = {}

local ffi = require('ffi')
local math = require('math')

local libh264bitstream = ffi.load('h264bitstream')

ffi.cdef([[
    struct FILE;
    typedef struct FILE FILE;
    typedef struct
    {
     uint8_t* start;
     uint8_t* p;
     uint8_t* end;
     int bits_left;
    } bs_t;
    static bs_t* bs_new(uint8_t* buf, size_t size);
    static void bs_free(bs_t* b);
    static bs_t* bs_clone( bs_t* dest, const bs_t* src );
    static bs_t* bs_init(bs_t* b, uint8_t* buf, size_t size);
    static uint32_t bs_byte_aligned(bs_t* b);
    static int bs_eof(bs_t* b);
    static int bs_overrun(bs_t* b);
    static int bs_pos(bs_t* b);
    static uint32_t bs_peek_u1(bs_t* b);
    static uint32_t bs_read_u1(bs_t* b);
    static uint32_t bs_read_u(bs_t* b, int n);
    static uint32_t bs_read_f(bs_t* b, int n);
    static uint32_t bs_read_u8(bs_t* b);
    static uint32_t bs_read_ue(bs_t* b);
    static int32_t bs_read_se(bs_t* b);
    static void bs_write_u1(bs_t* b, uint32_t v);
    static void bs_write_u(bs_t* b, int n, uint32_t v);
    static void bs_write_f(bs_t* b, int n, uint32_t v);
    static void bs_write_u8(bs_t* b, uint32_t v);
    static void bs_write_ue(bs_t* b, uint32_t v);
    static void bs_write_se(bs_t* b, int32_t v);
    static int bs_read_bytes(bs_t* b, uint8_t* buf, int len);
    static int bs_write_bytes(bs_t* b, uint8_t* buf, int len);
    static int bs_skip_bytes(bs_t* b, int len);
    static uint32_t bs_next_bits(bs_t* b, int nbits);
    static inline bs_t* bs_init(bs_t* b, uint8_t* buf, size_t size)
    {
        b->start = buf;
        b->p = buf;
        b->end = buf + size;
        b->bits_left = 8;
        return b;
    }
    static inline bs_t* bs_new(uint8_t* buf, size_t size)
    {
        bs_t* b = (bs_t*)malloc(sizeof(bs_t));
        bs_init(b, buf, size);
        return b;
    }
    static inline void bs_free(bs_t* b)
    {
        free(b);
    }
    static inline bs_t* bs_clone(bs_t* dest, const bs_t* src)
    {
        dest->start = src->p;
        dest->p = src->p;
        dest->end = src->end;
        dest->bits_left = src->bits_left;
        return dest;
    }
    static inline uint32_t bs_byte_aligned(bs_t* b)
    {
        return (b->bits_left == 8);
    }
    static inline int bs_eof(bs_t* b) { if (b->p >= b->end) { return 1; } else { return 0; } }
    static inline int bs_overrun(bs_t* b) { if (b->p > b->end) { return 1; } else { return 0; } }
    static inline int bs_pos(bs_t* b) { if (b->p > b->end) { return (b->end - b->start); } else { return (b->p - b->start); } }
    static inline int bs_bytes_left(bs_t* b) { return (b->end - b->p); }
    static inline uint32_t bs_read_u1(bs_t* b)
    {
        uint32_t r = 0;
        b->bits_left--;
        if (! bs_eof(b))
        {
            r = ((*(b->p)) >> b->bits_left) & 0x01;
        }
        if (b->bits_left == 0) { b->p ++; b->bits_left = 8; }
        return r;
    }
    static inline void bs_skip_u1(bs_t* b)
    {
        b->bits_left--;
        if (b->bits_left == 0) { b->p ++; b->bits_left = 8; }
    }
    static inline uint32_t bs_peek_u1(bs_t* b)
    {
        uint32_t r = 0;
        if (! bs_eof(b))
        {
            r = ((*(b->p)) >> ( b->bits_left - 1 )) & 0x01;
        }
        return r;
    }
    static inline uint32_t bs_read_u(bs_t* b, int n)
    {
        uint32_t r = 0;
        int i;
        for (i = 0; i < n; i++)
        {
            r |= ( bs_read_u1(b) << ( n - i - 1 ) );
        }
        return r;
    }
    static inline void bs_skip_u(bs_t* b, int n)
    {
        int i;
        for ( i = 0; i < n; i++ )
        {
            bs_skip_u1( b );
        }
    }
    static inline uint32_t bs_read_f(bs_t* b, int n) { return bs_read_u(b, n); }
    static inline uint32_t bs_read_u8(bs_t* b)
    {
        if (b->bits_left == 8 && ! bs_eof(b))
        {
            uint32_t r = b->p[0];
            b->p++;
            return r;
        }
        return bs_read_u(b, 8);
    }
    static inline uint32_t bs_read_ue(bs_t* b)
    {
        int32_t r = 0;
        int i = 0;
        while( (bs_read_u1(b) == 0) && (i < 32) && (!bs_eof(b)) )
        {
            i++;
        }
        r = bs_read_u(b, i);
        r += (1 << i) - 1;
        return r;
    }
    static inline int32_t bs_read_se(bs_t* b)
    {
        int32_t r = bs_read_ue(b);
        if (r & 0x01)
        {
            r = (r+1)/2;
        }
        else
        {
            r = -(r/2);
        }
        return r;
    }
    static inline void bs_write_u1(bs_t* b, uint32_t v)
    {
        b->bits_left--;
        if (! bs_eof(b))
        {
            (*(b->p)) &= ~(0x01 << b->bits_left);
            (*(b->p)) |= ((v & 0x01) << b->bits_left);
        }
        if (b->bits_left == 0) { b->p ++; b->bits_left = 8; }
    }
    static inline void bs_write_u(bs_t* b, int n, uint32_t v)
    {
        int i;
        for (i = 0; i < n; i++)
        {
            bs_write_u1(b, (v >> ( n - i - 1 ))&0x01 );
        }
    }
    static inline void bs_write_f(bs_t* b, int n, uint32_t v) { bs_write_u(b, n, v); }
    static inline void bs_write_u8(bs_t* b, uint32_t v)
    {
        if (b->bits_left == 8 && ! bs_eof(b))
        {
            b->p[0] = v;
            b->p++;
            return;
        }
        bs_write_u(b, 8, v);
    }
    static inline void bs_write_ue(bs_t* b, uint32_t v)
    {
        static const int len_table[256] =
        {
            1,
            1,
            2,2,
            3,3,3,3,
            4,4,4,4,4,4,4,4,
            5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
            6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
            6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
            7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
            7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
            7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
            7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
            8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        };
        int len;
        if (v == 0)
        {
            bs_write_u1(b, 1);
        }
        else
        {
            v++;
            if (v >= 0x01000000)
            {
                len = 24 + len_table[ v >> 24 ];
            }
            else if(v >= 0x00010000)
            {
                len = 16 + len_table[ v >> 16 ];
            }
            else if(v >= 0x00000100)
            {
                len = 8 + len_table[ v >> 8 ];
            }
            else
            {
                len = len_table[ v ];
            }
            bs_write_u(b, 2*len-1, v);
        }
    }
    static inline void bs_write_se(bs_t* b, int32_t v)
    {
        if (v <= 0)
        {
            bs_write_ue(b, -v*2);
        }
        else
        {
            bs_write_ue(b, v*2 - 1);
        }
    }
    static inline int bs_read_bytes(bs_t* b, uint8_t* buf, int len)
    {
        int actual_len = len;
        if (b->end - b->p < actual_len) { actual_len = b->end - b->p; }
        if (actual_len < 0) { actual_len = 0; }
        memcpy(buf, b->p, actual_len);
        if (len < 0) { len = 0; }
        b->p += len;
        return actual_len;
    }
    static inline int bs_write_bytes(bs_t* b, uint8_t* buf, int len)
    {
        int actual_len = len;
        if (b->end - b->p < actual_len) { actual_len = b->end - b->p; }
        if (actual_len < 0) { actual_len = 0; }
        memcpy(b->p, buf, actual_len);
        if (len < 0) { len = 0; }
        b->p += len;
        return actual_len;
    }
    static inline int bs_skip_bytes(bs_t* b, int len)
    {
        int actual_len = len;
        if (b->end - b->p < actual_len) { actual_len = b->end - b->p; }
        if (actual_len < 0) { actual_len = 0; }
        if (len < 0) { len = 0; }
        b->p += len;
        return actual_len;
    }
    static inline uint32_t bs_next_bits(bs_t* bs, int nbits)
    {
       bs_t b;
       bs_clone(&b,bs);
       return bs_read_u(&b, nbits);
    }
    static inline uint64_t bs_next_bytes(bs_t* bs, int nbytes)
    {
       int i = 0;
       uint64_t val = 0;
       if ( (nbytes > 8) || (nbytes < 1) ) { return 0; }
       if (bs->p + nbytes > bs->end) { return 0; }
       for ( i = 0; i < nbytes; i++ ) { val = ( val << 8 ) | bs->p[i]; }
       return val;
    }
    typedef struct
    {
        int payloadType;
        int payloadSize;
        uint8_t* payload;
    } sei_t;
    sei_t* sei_new();
    void sei_free(sei_t* s);
    typedef struct
    {
        int profile_idc;
        int constraint_set0_flag;
        int constraint_set1_flag;
        int constraint_set2_flag;
        int constraint_set3_flag;
        int constraint_set4_flag;
        int constraint_set5_flag;
        int reserved_zero_2bits;
        int level_idc;
        int seq_parameter_set_id;
        int chroma_format_idc;
        int residual_colour_transform_flag;
        int bit_depth_luma_minus8;
        int bit_depth_chroma_minus8;
        int qpprime_y_zero_transform_bypass_flag;
        int seq_scaling_matrix_present_flag;
          int seq_scaling_list_present_flag[8];
          int ScalingList4x4[6][16];
          int UseDefaultScalingMatrix4x4Flag[6];
          int ScalingList8x8[2][64];
          int UseDefaultScalingMatrix8x8Flag[2];
        int log2_max_frame_num_minus4;
        int pic_order_cnt_type;
          int log2_max_pic_order_cnt_lsb_minus4;
          int delta_pic_order_always_zero_flag;
          int offset_for_non_ref_pic;
          int offset_for_top_to_bottom_field;
          int num_ref_frames_in_pic_order_cnt_cycle;
          int offset_for_ref_frame[256];
        int num_ref_frames;
        int gaps_in_frame_num_value_allowed_flag;
        int pic_width_in_mbs_minus1;
        int pic_height_in_map_units_minus1;
        int frame_mbs_only_flag;
        int mb_adaptive_frame_field_flag;
        int direct_8x8_inference_flag;
        int frame_cropping_flag;
          int frame_crop_left_offset;
          int frame_crop_right_offset;
          int frame_crop_top_offset;
          int frame_crop_bottom_offset;
        int vui_parameters_present_flag;
        struct
        {
            int aspect_ratio_info_present_flag;
              int aspect_ratio_idc;
                int sar_width;
                int sar_height;
            int overscan_info_present_flag;
              int overscan_appropriate_flag;
            int video_signal_type_present_flag;
              int video_format;
              int video_full_range_flag;
              int colour_description_present_flag;
                int colour_primaries;
                int transfer_characteristics;
                int matrix_coefficients;
            int chroma_loc_info_present_flag;
              int chroma_sample_loc_type_top_field;
              int chroma_sample_loc_type_bottom_field;
            int timing_info_present_flag;
              int num_units_in_tick;
              int time_scale;
              int fixed_frame_rate_flag;
            int nal_hrd_parameters_present_flag;
            int vcl_hrd_parameters_present_flag;
              int low_delay_hrd_flag;
            int pic_struct_present_flag;
            int bitstream_restriction_flag;
              int motion_vectors_over_pic_boundaries_flag;
              int max_bytes_per_pic_denom;
              int max_bits_per_mb_denom;
              int log2_max_mv_length_horizontal;
              int log2_max_mv_length_vertical;
              int num_reorder_frames;
              int max_dec_frame_buffering;
        } vui;
        struct
        {
            int cpb_cnt_minus1;
            int bit_rate_scale;
            int cpb_size_scale;
              int bit_rate_value_minus1[32];
              int cpb_size_value_minus1[32];
              int cbr_flag[32];
            int initial_cpb_removal_delay_length_minus1;
            int cpb_removal_delay_length_minus1;
            int dpb_output_delay_length_minus1;
            int time_offset_length;
        } hrd;
    } sps_t;
    typedef struct
    {
        int pic_parameter_set_id;
        int seq_parameter_set_id;
        int entropy_coding_mode_flag;
        int pic_order_present_flag;
        int num_slice_groups_minus1;
        int slice_group_map_type;
          int run_length_minus1[8];
          int top_left[8];
          int bottom_right[8];
          int slice_group_change_direction_flag;
          int slice_group_change_rate_minus1;
          int pic_size_in_map_units_minus1;
          int slice_group_id[256];
        int num_ref_idx_l0_active_minus1;
        int num_ref_idx_l1_active_minus1;
        int weighted_pred_flag;
        int weighted_bipred_idc;
        int pic_init_qp_minus26;
        int pic_init_qs_minus26;
        int chroma_qp_index_offset;
        int deblocking_filter_control_present_flag;
        int constrained_intra_pred_flag;
        int redundant_pic_cnt_present_flag;
        int _more_rbsp_data_present;
        int transform_8x8_mode_flag;
        int pic_scaling_matrix_present_flag;
           int pic_scaling_list_present_flag[8];
           int ScalingList4x4[6][16];
           int UseDefaultScalingMatrix4x4Flag[6];
           int ScalingList8x8[2][64];
           int UseDefaultScalingMatrix8x8Flag[2];
        int second_chroma_qp_index_offset;
    } pps_t;
    typedef struct
    {
        int first_mb_in_slice;
        int slice_type;
        int pic_parameter_set_id;
        int frame_num;
        int field_pic_flag;
          int bottom_field_flag;
        int idr_pic_id;
        int pic_order_cnt_lsb;
        int delta_pic_order_cnt_bottom;
        int delta_pic_order_cnt[ 2 ];
        int redundant_pic_cnt;
        int direct_spatial_mv_pred_flag;
        int num_ref_idx_active_override_flag;
        int num_ref_idx_l0_active_minus1;
        int num_ref_idx_l1_active_minus1;
        int cabac_init_idc;
        int slice_qp_delta;
        int sp_for_switch_flag;
        int slice_qs_delta;
        int disable_deblocking_filter_idc;
        int slice_alpha_c0_offset_div2;
        int slice_beta_offset_div2;
        int slice_group_change_cycle;
        struct
        {
            int luma_log2_weight_denom;
            int chroma_log2_weight_denom;
            int luma_weight_l0_flag[64];
            int luma_weight_l0[64];
            int luma_offset_l0[64];
            int chroma_weight_l0_flag[64];
            int chroma_weight_l0[64][2];
            int chroma_offset_l0[64][2];
            int luma_weight_l1_flag[64];
            int luma_weight_l1[64];
            int luma_offset_l1[64];
            int chroma_weight_l1_flag[64];
            int chroma_weight_l1[64][2];
            int chroma_offset_l1[64][2];
        } pwt;
        struct
        {
            int ref_pic_list_reordering_flag_l0;
            struct
            {
                int reordering_of_pic_nums_idc[64];
                int abs_diff_pic_num_minus1[64];
                int long_term_pic_num[64];
            } reorder_l0;
            int ref_pic_list_reordering_flag_l1;
            struct
            {
                int reordering_of_pic_nums_idc[64];
                int abs_diff_pic_num_minus1[64];
                int long_term_pic_num[64];
            } reorder_l1;
        } rplr;
        struct
        {
            int no_output_of_prior_pics_flag;
            int long_term_reference_flag;
            int adaptive_ref_pic_marking_mode_flag;
            int memory_management_control_operation[64];
            int difference_of_pic_nums_minus1[64];
            int long_term_pic_num[64];
            int long_term_frame_idx[64];
            int max_long_term_frame_idx_plus1[64];
        } drpm;
    } slice_header_t;
    typedef struct
    {
        int primary_pic_type;
    } aud_t;
    typedef struct
    {
        int forbidden_zero_bit;
        int nal_ref_idc;
        int nal_unit_type;
        void* parsed;
        int sizeof_parsed;
    } nal_t;
    typedef struct
    {
        int _is_initialized;
        int sps_id;
        int initial_cpb_removal_delay;
        int initial_cpb_delay_offset;
    } sei_buffering_t;
    typedef struct
    {
        int clock_timestamp_flag;
            int ct_type;
            int nuit_field_based_flag;
            int counting_type;
            int full_timestamp_flag;
            int discontinuity_flag;
            int cnt_dropped_flag;
            int n_frames;
            int seconds_value;
            int minutes_value;
            int hours_value;
            int seconds_flag;
            int minutes_flag;
            int hours_flag;
            int time_offset;
    } picture_timestamp_t;
    typedef struct
    {
      int _is_initialized;
      int cpb_removal_delay;
      int dpb_output_delay;
      int pic_struct;
      picture_timestamp_t clock_timestamps[3];
    } sei_picture_timing_t;
    typedef struct
    {
      int rbsp_size;
      uint8_t* rbsp_buf;
    } slice_data_rbsp_t;
    typedef struct
    {
        nal_t* nal;
        sps_t* sps;
        pps_t* pps;
        aud_t* aud;
        sei_t* sei;
        int num_seis;
        slice_header_t* sh;
        slice_data_rbsp_t* slice_data;
        sps_t* sps_table[32];
        pps_t* pps_table[256];
        sei_t** seis;
    } h264_stream_t;
    h264_stream_t* h264_new();
    void h264_free(h264_stream_t* h);
    int find_nal_unit(uint8_t* buf, int size, int* nal_start, int* nal_end);
    int rbsp_to_nal(const uint8_t* rbsp_buf, const int* rbsp_size, uint8_t* nal_buf, int* nal_size);
    int nal_to_rbsp(const uint8_t* nal_buf, int* nal_size, uint8_t* rbsp_buf, int* rbsp_size);
    int read_nal_unit(h264_stream_t* h, uint8_t* buf, int size);
    int peek_nal_unit(h264_stream_t* h, uint8_t* buf, int size);
    void read_seq_parameter_set_rbsp(h264_stream_t* h, bs_t* b);
    void read_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag );
    void read_vui_parameters(h264_stream_t* h, bs_t* b);
    void read_hrd_parameters(h264_stream_t* h, bs_t* b);
    void read_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b);
    void read_sei_rbsp(h264_stream_t* h, bs_t* b);
    void read_sei_message(h264_stream_t* h, bs_t* b);
    void read_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b);
    void read_end_of_seq_rbsp(h264_stream_t* h, bs_t* b);
    void read_end_of_stream_rbsp(h264_stream_t* h, bs_t* b);
    void read_filler_data_rbsp(h264_stream_t* h, bs_t* b);
    void read_slice_layer_rbsp(h264_stream_t* h, bs_t* b);
    void read_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b);
    void read_rbsp_trailing_bits(h264_stream_t* h, bs_t* b);
    void read_slice_header(h264_stream_t* h, bs_t* b);
    void read_ref_pic_list_reordering(h264_stream_t* h, bs_t* b);
    void read_pred_weight_table(h264_stream_t* h, bs_t* b);
    void read_dec_ref_pic_marking(h264_stream_t* h, bs_t* b);
    int more_rbsp_trailing_data(h264_stream_t* h, bs_t* b);
    int write_nal_unit(h264_stream_t* h, uint8_t* buf, int size);
    void write_seq_parameter_set_rbsp(h264_stream_t* h, bs_t* b);
    void write_scaling_list(bs_t* b, int* scalingList, int sizeOfScalingList, int* useDefaultScalingMatrixFlag );
    void write_vui_parameters(h264_stream_t* h, bs_t* b);
    void write_hrd_parameters(h264_stream_t* h, bs_t* b);
    void write_pic_parameter_set_rbsp(h264_stream_t* h, bs_t* b);
    void write_sei_rbsp(h264_stream_t* h, bs_t* b);
    void write_sei_message(h264_stream_t* h, bs_t* b);
    void write_access_unit_delimiter_rbsp(h264_stream_t* h, bs_t* b);
    void write_end_of_seq_rbsp(h264_stream_t* h, bs_t* b);
    void write_end_of_stream_rbsp(h264_stream_t* h, bs_t* b);
    void write_filler_data_rbsp(h264_stream_t* h, bs_t* b);
    void write_slice_layer_rbsp(h264_stream_t* h, bs_t* b);
    void write_rbsp_slice_trailing_bits(h264_stream_t* h, bs_t* b);
    void write_rbsp_trailing_bits(h264_stream_t* h, bs_t* b);
    void write_slice_header(h264_stream_t* h, bs_t* b);
    void write_ref_pic_list_reordering(h264_stream_t* h, bs_t* b);
    void write_pred_weight_table(h264_stream_t* h, bs_t* b);
    void write_dec_ref_pic_marking(h264_stream_t* h, bs_t* b);
    int read_debug_nal_unit(h264_stream_t* h, uint8_t* buf, int size);
    void debug_sps(sps_t* sps);
    void debug_pps(pps_t* pps);
    void debug_slice_header(slice_header_t* sh);
    void debug_nal(h264_stream_t* h, nal_t* nal);
    void debug_bytes(uint8_t* buf, int len);
    void read_sei_payload( h264_stream_t* h, bs_t* b, int payloadType, int payloadSize);
    void write_sei_payload( h264_stream_t* h, bs_t* b, int payloadType, int payloadSize);
    extern FILE* h264_dbgfile;
]])

h264bitstream.SEI_TYPE_BUFFERING_PERIOD = 0
h264bitstream.SEI_TYPE_PIC_TIMING = 1
h264bitstream.SEI_TYPE_PAN_SCAN_RECT = 2
h264bitstream.SEI_TYPE_FILLER_PAYLOAD = 3
h264bitstream.SEI_TYPE_USER_DATA_REGISTERED_ITU_T_T35 = 4
h264bitstream.SEI_TYPE_USER_DATA_UNREGISTERED = 5
h264bitstream.SEI_TYPE_RECOVERY_POINT = 6
h264bitstream.SEI_TYPE_DEC_REF_PIC_MARKING_REPETITION = 7
h264bitstream.SEI_TYPE_SPARE_PIC = 8
h264bitstream.SEI_TYPE_SCENE_INFO = 9
h264bitstream.SEI_TYPE_SUB_SEQ_INFO = 10
h264bitstream.SEI_TYPE_SUB_SEQ_LAYER_CHARACTERISTICS = 11
h264bitstream.SEI_TYPE_SUB_SEQ_CHARACTERISTICS = 12
h264bitstream.SEI_TYPE_FULL_FRAME_FREEZE = 13
h264bitstream.SEI_TYPE_FULL_FRAME_FREEZE_RELEASE = 14
h264bitstream.SEI_TYPE_FULL_FRAME_SNAPSHOT = 15
h264bitstream.SEI_TYPE_PROGRESSIVE_REFINEMENT_SEGMENT_START = 16
h264bitstream.SEI_TYPE_PROGRESSIVE_REFINEMENT_SEGMENT_END = 17
h264bitstream.SEI_TYPE_MOTION_CONSTRAINED_SLICE_GROUP_SET = 18
h264bitstream.SEI_TYPE_FILM_GRAIN_CHARACTERISTICS = 19
h264bitstream.SEI_TYPE_DEBLOCKING_FILTER_DISPLAY_PREFERENCE = 20
h264bitstream.SEI_TYPE_STEREO_VIDEO_INFO = 21
h264bitstream.cabac = 0
h264bitstream.I_PCM = 0
h264bitstream.I_NxN = 0
h264bitstream.P_8x8ref0 = 0
h264bitstream.Intra_4x4 = 0
h264bitstream.Intra_8x8 = 0
h264bitstream.Intra_16x16 = 0
h264bitstream.Direct = 0
h264bitstream.Pred_L0 = 0
h264bitstream.Pred_L1 = 0
h264bitstream.B_Direct_8x8 = 0
h264bitstream.B_Direct_16x16 = 0
h264bitstream.MbWidthC = 8
h264bitstream.MbHeightC = 8
h264bitstream.SubWidthC = 2
h264bitstream.SubHeightC = 2
h264bitstream.NAL_REF_IDC_PRIORITY_HIGHEST = 3
h264bitstream.NAL_REF_IDC_PRIORITY_HIGH = 2
h264bitstream.NAL_REF_IDC_PRIORITY_LOW = 1
h264bitstream.NAL_REF_IDC_PRIORITY_DISPOSABLE = 0
h264bitstream.NAL_UNIT_TYPE_UNSPECIFIED = 0
h264bitstream.NAL_UNIT_TYPE_CODED_SLICE_NON_IDR = 1
h264bitstream.NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_A = 2
h264bitstream.NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_B = 3
h264bitstream.NAL_UNIT_TYPE_CODED_SLICE_DATA_PARTITION_C = 4
h264bitstream.NAL_UNIT_TYPE_CODED_SLICE_IDR = 5
h264bitstream.NAL_UNIT_TYPE_SEI = 6
h264bitstream.NAL_UNIT_TYPE_SPS = 7
h264bitstream.NAL_UNIT_TYPE_PPS = 8
h264bitstream.NAL_UNIT_TYPE_AUD = 9
h264bitstream.NAL_UNIT_TYPE_END_OF_SEQUENCE = 10
h264bitstream.NAL_UNIT_TYPE_END_OF_STREAM = 11
h264bitstream.NAL_UNIT_TYPE_FILLER = 12
h264bitstream.NAL_UNIT_TYPE_SPS_EXT = 13
h264bitstream.NAL_UNIT_TYPE_CODED_SLICE_AUX = 19
h264bitstream.SH_SLICE_TYPE_P = 0
h264bitstream.SH_SLICE_TYPE_B = 1
h264bitstream.SH_SLICE_TYPE_I = 2
h264bitstream.SH_SLICE_TYPE_SP = 3
h264bitstream.SH_SLICE_TYPE_SI = 4
h264bitstream.SH_SLICE_TYPE_P_ONLY = 5
h264bitstream.SH_SLICE_TYPE_B_ONLY = 6
h264bitstream.SH_SLICE_TYPE_I_ONLY = 7
h264bitstream.SH_SLICE_TYPE_SP_ONLY = 8
h264bitstream.SH_SLICE_TYPE_SI_ONLY = 9
h264bitstream.SAR_Unspecified = 0
h264bitstream.SAR_1_1 = 1
h264bitstream.SAR_12_11 = 2
h264bitstream.SAR_10_11 = 3
h264bitstream.SAR_16_11 = 4
h264bitstream.SAR_40_33 = 5
h264bitstream.SAR_24_11 = 6
h264bitstream.SAR_20_11 = 7
h264bitstream.SAR_32_11 = 8
h264bitstream.SAR_80_33 = 9
h264bitstream.SAR_18_11 = 10
h264bitstream.SAR_15_11 = 11
h264bitstream.SAR_64_33 = 12
h264bitstream.SAR_160_99 = 13
h264bitstream.SAR_Extended = 255
h264bitstream.RPLR_IDC_ABS_DIFF_ADD = 0
h264bitstream.RPLR_IDC_ABS_DIFF_SUBTRACT = 1
h264bitstream.RPLR_IDC_LONG_TERM = 2
h264bitstream.RPLR_IDC_END = 3
h264bitstream.MMCO_END = 0
h264bitstream.MMCO_SHORT_TERM_UNUSED = 1
h264bitstream.MMCO_LONG_TERM_UNUSED = 2
h264bitstream.MMCO_SHORT_TERM_TO_LONG_TERM = 3
h264bitstream.MMCO_LONG_TERM_MAX_INDEX = 4
h264bitstream.MMCO_ALL_UNUSED = 5
h264bitstream.MMCO_CURRENT_TO_LONG_TERM = 6
h264bitstream.AUD_PRIMARY_PIC_TYPE_I = 0
h264bitstream.AUD_PRIMARY_PIC_TYPE_IP = 1
h264bitstream.AUD_PRIMARY_PIC_TYPE_IPB = 2
h264bitstream.AUD_PRIMARY_PIC_TYPE_SI = 3
h264bitstream.AUD_PRIMARY_PIC_TYPE_SISP = 4
h264bitstream.AUD_PRIMARY_PIC_TYPE_ISI = 5
h264bitstream.AUD_PRIMARY_PIC_TYPE_ISIPSP = 6
h264bitstream.AUD_PRIMARY_PIC_TYPE_ISIPSPB = 7
h264bitstream.H264_PROFILE_BASELINE = 66
h264bitstream.H264_PROFILE_MAIN = 77
h264bitstream.H264_PROFILE_EXTENDED = 88
h264bitstream.H264_PROFILE_HIGH = 100

function h264bitstream.new()
    return libh264bitstream.h264_new()
end

function h264bitstream.free(stream)
    libh264bitstream.h264_free(stream)
end

function h264bitstream.rbsp_to_nal(data, size)
    local rbsp_size = ffi.new('int[1]')
    rbsp_size[0] = size
    local nal = ffi.new('uint8_t[?]', size + 1024)
    local nal_size = ffi.new('int[1]')
    nal_size[0] = ffi.sizeof(nal)
    local n = libh264bitstream.rbsp_to_nal(data, rbsp_size, nal, nal_size);
    assert(n <= nal_size[0])
    return nal, n
end

local code = ffi.new('uint8_t[4]', 0, 0, 0, 1)

function h264bitstream.write_nal_unit(stream, buffer, size)
    -- https://github.com/aizvorski/h264bitstream/issues/5
    local n = libh264bitstream.write_nal_unit(stream, buffer + 3, size - 3)
    n = n + 3
    ffi.copy(buffer, code, 4)
    return n
end

return h264bitstream
