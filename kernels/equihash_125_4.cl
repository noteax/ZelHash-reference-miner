// ZelCash OpenCL Miner
// OpenCL Mining Sources for Equihash 125/4
// Copyright 2018 Wilke Trei


#define bucketSize 8672


__kernel void clearCounter (
		__global uint4 * counters,
		__global uint4 * res) {

	uint gId = get_global_id(0);
	counters[gId] = (uint4) 0;

	if (gId == 0) {
		res[0] = (uint4) 0; 
	}
}

/*
	This function swaps the order of bits in each byte from low to high endian.
	This is required for having the xor bits in right order 
*/
inline uint swapBitOrder(uint input) {
	uint tmp0 = input & 0x0F0F0F0F;
	uint tmp1 = input & 0xF0F0F0F0;

	tmp0 = tmp0 << 4;
	tmp1 = tmp1 >> 4;

	uint tmpIn = tmp0 | tmp1;
	
	tmp0 = tmpIn & 0x33333333;
	tmp1 = tmpIn & 0xCCCCCCCC;

	tmp0 = tmp0 << 2;
	tmp1 = tmp1 >> 2;

	tmpIn = tmp0 | tmp1;

	tmp0 = tmpIn & 0x55555555;
	tmp1 = tmpIn & 0xAAAAAAAA;

	tmp0 = tmp0 << 1;
	tmp1 = tmp1 >> 1;

	return tmp0 | tmp1;
}

__constant ulong blake_iv[] =
{
    0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
    0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
    0x510e527fade682d1, 0x9b05688c2b3e6c1f,
    0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
};


uint4 shr_4(uint4 input, uint sh) {
	uint4 tmp = (input >> sh);
	uint4 tmp2 = (input << 32-sh);

	tmp.s01 |= tmp2.s12;
	tmp.s2  |= tmp2.s3;

	return tmp;
}

/* 32 bit rotate functions have better performance then the 64 bit buildins */
inline static uint2 ror64(const uint2 x, const uint y)
{
    return (uint2)(((x).x>>y)^((x).y<<(32-y)),((x).y>>y)^((x).x<<(32-y)));
}
inline static uint2 ror64_2(const uint2 x, const uint y)
{
    return (uint2)(((x).y>>(y-32))^((x).x<<(64-y)),((x).x>>(y-32))^((x).y<<(64-y)));
}

#define gFunc(va, vb, vc, vd, x, y) \
va = (va + vb + x); \
((uint2*)&vd)[0] = ((uint2*)&vd)[0].yx ^ ((uint2*)&va)[0].yx; \
vc = (vc + vd); \
((uint2*)&vb)[0] = ror64( ((uint2*)&vb)[0] ^ ((uint2*)&vc)[0], 24U); \
va = (va + vb + y); \
((uint2*)&vd)[0] = ror64( ((uint2*)&vd)[0] ^ ((uint2*)&va)[0], 16U); \
vc = (vc + vd); \
((uint2*)&vb)[0] = ror64_2( ((uint2*)&vb)[0] ^ ((uint2*)&vc)[0], 63U);



__kernel void round0(
		__global uint4 * outputLo,
		__global uint * outputHi,
		__global uint * counters,
		ulong8 blake_state,
		uint nonce ) {

	uint tId = get_global_id(0);

	ulong word1 = ((ulong)tId << 32) | nonce;
    ulong v[16];

	// init vector v
	v[0] = blake_state.s0;
	v[1] = blake_state.s1;
	v[2] = blake_state.s2;
	v[3] = blake_state.s3;
	v[4] = blake_state.s4;
	v[5] = blake_state.s5;
	v[6] = blake_state.s6;
	v[7] = blake_state.s7;
	v[8] =  blake_iv[0];
	v[9] =  blake_iv[1];
	v[10] = blake_iv[2];
	v[11] = blake_iv[3];
	v[12] = blake_iv[4];
	v[13] = blake_iv[5];
	v[14] = blake_iv[6];
	v[15] = blake_iv[7];
	// length of data - 32 byte work + 8 byte nonce + 4 byte index
	v[12] ^= 144; 
	v[14] ^= (ulong)-1;

	// round 1
	gFunc(v[0], v[4], v[8],  v[12], 0, word1);
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 2
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14],	0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], word1, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 3
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, word1);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 4
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);
	gFunc(v[1], v[5], v[9],  v[13], 0, word1);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 5
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, word1);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 6
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], word1, 0);
	// round 7
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], word1, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 8
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, word1);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 9
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], word1, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 10
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], word1, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 11
	gFunc(v[0], v[4], v[8],  v[12], 0, word1);
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14], 0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], 0, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);
	// round 12
	gFunc(v[0], v[4], v[8],  v[12], 0, 0);		
	gFunc(v[1], v[5], v[9],  v[13], 0, 0);
	gFunc(v[2], v[6], v[10], v[14],	0, 0);
	gFunc(v[3], v[7], v[11], v[15], 0, 0);
	gFunc(v[0], v[5], v[10], v[15], word1, 0);
	gFunc(v[1], v[6], v[11], v[12], 0, 0);
	gFunc(v[2], v[7], v[8],  v[13], 0, 0);
	gFunc(v[3], v[4], v[9],  v[14], 0, 0);

    v[0] = v[0] ^ blake_state.s0 ^ v[8];
    v[1] = v[1] ^ blake_state.s1 ^ v[9];
    v[2] = v[2] ^ blake_state.s2 ^ v[10];
    v[3] = v[3] ^ blake_state.s3 ^ v[11];
    v[4] = v[4] ^ blake_state.s4 ^ v[12];
    v[5] = v[5] ^ blake_state.s5 ^ v[13];
    v[6] = v[6] ^ blake_state.s6 ^ v[14];
	v[7] = v[7] ^ blake_state.s7 ^ v[15]; 

	uint8 output;
	uint pos;
	uint bucket;

	__local uint dataShare[4096];						// prepare for pipeline change

	uint lId = get_local_id(0);

	for (uint i=0; i<8; i++) {
		dataShare[16*lId+2*i+0] = v[i] ; 
		dataShare[16*lId+2*i+1] = v[i] >> 32; 		
	}									// Now all data of the block is shared
	
	barrier(CLK_LOCAL_MEM_FENCE); 						// Barrier is only needed for CPU mining, can be removed on modern GPUs
		
	uint v2[16];								// Only need first 15 words
	uint start = lId & 0xF0; 						// Get rid of lower 4 bit

	for (uint i=0; i<16; i++) {
		v2[i] = 0;
		for (uint j = start; j<=lId; j++) v2[i] += dataShare[16*j + i];
		v2[i] = swapBitOrder(v2[i]);
	}				

	output.s0 = v2[0]; 							// First element are bytes 0 to 15 
	output.s1 = v2[1];
	output.s2 = v2[2]; 
	output.s3 = v2[3] & 0x1FFFFFFF;						// Only lower 29 bits  

	 					
	output.s4 = (tId << 2); 
	bucket = output.s0 & 0x1FFF;						// We will sort the element into 2^13 
										// buckets of maximal size "bucketSize"	
	pos = atomic_inc(&counters[bucket]);
	output.lo = shr_4(output.lo,13);
		
	if (pos < bucketSize) {
		outputLo[bucket*bucketSize+pos] = output.lo;
		outputHi[bucket*bucketSize+pos] = output.s4;
	}


	output.s0 = v2[4]; 							// First element are bytes 15 to 31 
	output.s1 = v2[5];
	output.s2 = v2[6]; 
	output.s3 = v2[7] & 0x1FFFFFFF;						// Only lower 29 bits  
	 					
	output.s4 = (tId << 2)+1; 
	bucket = output.s0 & 0x1FFF;						// We will sort the element into 2^13 
										// buckets of maximal size "bucketSize"	
	pos = atomic_inc(&counters[bucket]);
	output.lo = shr_4(output.lo,13);
		
	if (pos < bucketSize) {
		outputLo[bucket*bucketSize+pos] = output.lo;
		outputHi[bucket*bucketSize+pos] = output.s4;
	}


	output.s0 = v2[8]; 							// First element are bytes 32 to 47 
	output.s1 = v2[9];
	output.s2 = v2[10]; 
	output.s3 = v2[11] & 0x1FFFFFFF;					// Only lower 29 bits  
	 					
	output.s4 = (tId << 2)+2; 
	bucket = output.s0 & 0x1FFF;						// We will sort the element into 2^13 
										// buckets of maximal size "bucketSize"	
	pos = atomic_inc(&counters[bucket]);
	output.lo = shr_4(output.lo,13);
		
	if (pos < bucketSize) {
		outputLo[bucket*bucketSize+pos] = output.lo;
		outputHi[bucket*bucketSize+pos] = output.s4;
	}


	output.s0 = v2[12]; 							// First element are bytes 48 to 63 
	output.s1 = v2[13];
	output.s2 = v2[14]; 
	output.s3 = v2[15] & 0x1FFFFFFF;					// Only lower 29 bits  
	 					
	output.s4 = (tId << 2)+3; 
	bucket = output.s0 & 0x1FFF;						// We will sort the element into 2^13 
										// buckets of maximal size "bucketSize"	
	pos = atomic_inc(&counters[bucket]);
	output.lo = shr_4(output.lo,13);
		
	if (pos < bucketSize) {
		outputLo[bucket*bucketSize+pos] = output.lo;
		outputHi[bucket*bucketSize+pos] = output.s4;
	}
}


void masking4(uint4 input0, uint id, __local uint* scratch, __local uint* tab , __local uint* cnt, uint mask) {
	if ((input0.s0 & 0x7) == mask) {
		uint pos = atomic_inc(&cnt[0]);
		if (pos < 1216) {
			uint value  = atomic_xchg(&tab[(input0.s0 >> 3) & 0x1FF], pos); 
			scratch[pos]      = input0.s0;	
			scratch[1216+pos] = input0.s1;
			scratch[2432+pos] = input0.s2;
			scratch[3648+pos] = input0.s3;
			scratch[4864+pos] = value; 					
			scratch[6080+pos] = id;
		}
	}
}


__kernel __attribute__((reqd_work_group_size(256, 1, 1))) void round1 (				// Round 1
		__global uint4 * input0,
		__global uint4 * output0,
		__global uint * counters) {
	uint lId = get_local_id(0);
	uint grp = get_group_id(0); 

	uint bucket = grp >> 3;
	uint mask = (grp & 7);

	__local uint scratch[7296];
	
	__local uint * scratch0 = &scratch[0];
	__local uint * scratch1 = &scratch[1216];
	__local uint * scratch2 = &scratch[2432];
	__local uint * scratch3 = &scratch[3648];
	__local uint * scratch4 = &scratch[4864];
	__local uint * scratch5 = &scratch[6080];

	__local uint tab[512];
	__local uint iCNT[2];

	__global uint * inCounter = &counters[0];
	__global uint * outCounter = &counters[8192];

	if (lId == 0) {
		iCNT[1] = 0;
		iCNT[0] = min(inCounter[bucket],(uint) bucketSize);
	} 

	tab[lId] = 0xFFF;
	tab[lId+256] = 0xFFF;

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ofs = bucket*bucketSize;	

	masking4(input0[ofs+lId], lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+256+lId], 256+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+512+lId], 512+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+768+lId], 768+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+1024+lId], 1024+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1280+lId], 1280+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1536+lId], 1536+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1792+lId], 1792+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+2048+lId], 2048+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2304+lId], 2304+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2560+lId], 2560+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2816+lId], 2816+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+3072+lId], 3072+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3328+lId], 3328+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3584+lId], 3584+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3840+lId], 3840+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+4096+lId], 4096+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4352+lId], 4352+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4608+lId], 4608+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4864+lId], 4864+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+5120+lId], 5120+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5376+lId], 5376+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5632+lId], 5632+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5888+lId], 5888+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+6144+lId], 6144+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6400+lId], 6400+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6656+lId], 6656+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6912+lId], 6912+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+7168+lId], 7168+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+7424+lId], 7424+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7680) < iCNT[0]) masking4(input0[ofs+7680+lId], 7680+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7936) < iCNT[0]) masking4(input0[ofs+7936+lId], 7936+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	if ((lId + 8192) < iCNT[0]) masking4(input0[ofs+8192+lId], 8192+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 8448) < iCNT[0]) masking4(input0[ofs+8448+lId], 8448+lId, &scratch[0], &tab[0], &iCNT[1], mask);
		
	barrier(CLK_LOCAL_MEM_FENCE);	

	uint inLim = min(iCNT[1], (uint) 1216);

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ownPos = lId;
	uint own = scratch4[ownPos];
	uint othPos = own;
	uint buck, pos;
	uint cnt=0;

	uint8 outputEl;
	
	while (ownPos < inLim) {
		uint addr = (othPos < inLim) ? othPos : ownPos+256;
		uint elem = scratch4[addr];
		
		if (othPos < inLim) {
			outputEl.s0 = scratch0[ownPos] ^ scratch0[othPos];	
			outputEl.s1 = scratch1[ownPos] ^ scratch1[othPos];
			if (outputEl.s1 != 0) {
				buck = (outputEl.s0 >> 12) & 0x1FFF;
				pos = atomic_inc(&outCounter[buck]);

				outputEl.s2 = scratch2[ownPos] ^ scratch2[othPos];	
				outputEl.s3 = scratch3[ownPos] ^ scratch3[othPos];

				outputEl.lo = shr_4(outputEl.lo,25); 			// Shift away 25 bits

				// Elements have 2*14 bit index plus 13 bit bucket
				// So 125 - 25 - 13 = 87 bit payload plus 41 bit index tree
				// 128 bit total - fit exactly one uint4 :D 

				outputEl.s3 = scratch5[ownPos];
				outputEl.s3 |= (scratch5[othPos] << 14);
				outputEl.s3 |= (bucket << 28);

				outputEl.s2 |= (bucket >> 4) << 23; 

				if (pos < bucketSize) {
					pos += buck*bucketSize;
					output0[pos] = outputEl.lo;
				}
			}
		} else { 
			own = elem;
			ownPos += 256;
		}

		othPos = elem;
		ownPos = (cnt<40) ? ownPos : inLim;
		cnt++;
	} 
}


__kernel __attribute__((reqd_work_group_size(256, 1, 1))) void round2 (				// Round 2
		__global uint4 * input0,
		__global uint4 * output0,
		__global uint * counters) {
	uint lId = get_local_id(0);
	uint grp = get_group_id(0); 

	uint bucket = grp >> 3;
	uint mask = (grp & 7);

	__local uint scratch[7296];
	
	__local uint * scratch0 = &scratch[0];
	__local uint * scratch1 = &scratch[1216];
	__local uint * scratch2 = &scratch[2432];
	__local uint * scratch3 = &scratch[3648];
	__local uint * scratch4 = &scratch[4864];
	__local uint * scratch5 = &scratch[6080];

	__local uint tab[512];
	__local uint iCNT[2];

	__global uint * inCounter = &counters[8192];
	__global uint * outCounter = &counters[16384];

	if (lId == 0) {
		iCNT[1] = 0;
		iCNT[0] = min(inCounter[bucket],(uint) bucketSize);
	} 

	tab[lId] = 0xFFF;
	tab[lId+256] = 0xFFF;

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ofs = bucket*bucketSize;	

	masking4(input0[ofs+lId], ofs+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+256+lId], ofs+256+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+512+lId], ofs+512+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+768+lId], ofs+768+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+1024+lId], ofs+1024+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1280+lId], ofs+1280+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1536+lId], ofs+1536+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1792+lId], ofs+1792+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+2048+lId], ofs+2048+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2304+lId], ofs+2304+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2560+lId], ofs+2560+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2816+lId], ofs+2816+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+3072+lId], ofs+3072+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3328+lId], ofs+3328+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3584+lId], ofs+3584+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3840+lId], ofs+3840+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+4096+lId], ofs+4096+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4352+lId], ofs+4352+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4608+lId], ofs+4608+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4864+lId], ofs+4864+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+5120+lId], ofs+5120+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5376+lId], ofs+5376+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5632+lId], ofs+5632+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5888+lId], ofs+5888+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+6144+lId], ofs+6144+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6400+lId], ofs+6400+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6656+lId], ofs+6656+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6912+lId], ofs+6912+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+7168+lId], ofs+7168+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+7424+lId], ofs+7424+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7680) < iCNT[0]) masking4(input0[ofs+7680+lId], ofs+7680+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7936) < iCNT[0]) masking4(input0[ofs+7936+lId], ofs+7936+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	if ((lId + 8192) < iCNT[0]) masking4(input0[ofs+8192+lId], ofs+8192+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 8448) < iCNT[0]) masking4(input0[ofs+8448+lId], ofs+8448+lId, &scratch[0], &tab[0], &iCNT[1], mask);
		
	barrier(CLK_LOCAL_MEM_FENCE);	

	uint inLim = min(iCNT[1], (uint) 1216);

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ownPos = lId;
	uint own = scratch4[ownPos];
	uint othPos = own;
	uint buck, pos;
	uint cnt=0;

	uint8 outputEl;
	
	while (ownPos < inLim) {
		uint addr = (othPos < inLim) ? othPos : ownPos+256;
		uint elem = scratch4[addr];
		
		if (othPos < inLim) {
			outputEl.s0 = scratch0[ownPos] ^ scratch0[othPos];	
			outputEl.s1 = scratch1[ownPos] ^ scratch1[othPos];
			if (outputEl.s1 != 0) {
				buck = (outputEl.s0 >> 12) & 0x1FFF;
				pos = atomic_inc(&outCounter[buck]);

				outputEl.s2 = (scratch2[ownPos] ^ scratch2[othPos]) & 0x7FFFFF;	
				outputEl.s3 = 0;

				outputEl.lo = shr_4(outputEl.lo,25); 			// Shift away 25 bits

				outputEl.s2 = scratch5[ownPos];
				outputEl.s3 = scratch5[othPos];

				if (pos < bucketSize) {
					pos += buck*bucketSize;
					output0[pos] = outputEl.lo;
				}
			}
		} else { 
			own = elem;
			ownPos += 256;
		}

		othPos = elem;
		ownPos = (cnt<40) ? ownPos : inLim;
		cnt++;
	} 
}


__kernel __attribute__((reqd_work_group_size(256, 1, 1))) void round3 (				// Round 3
		__global uint4 * input0,
		__global uint4 * output0,
		__global uint * counters) {
	uint lId = get_local_id(0);
	uint grp = get_group_id(0); 

	uint bucket = grp >> 3;
	uint mask = (grp & 7);

	__local uint scratch[7296];
	
	__local uint * scratch0 = &scratch[0];
	__local uint * scratch1 = &scratch[1216];
	__local uint * scratch2 = &scratch[2432];
	__local uint * scratch3 = &scratch[3648];
	__local uint * scratch4 = &scratch[4864];
	__local uint * scratch5 = &scratch[6080];

	__local uint tab[512];
	__local uint iCNT[2];

	__global uint * inCounter = &counters[16384];
	__global uint * outCounter = &counters[24576];

	if (lId == 0) {
		iCNT[1] = 0;
		iCNT[0] = min(inCounter[bucket],(uint) bucketSize);
	} 

	tab[lId] = 0xFFF;
	tab[lId+256] = 0xFFF;

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ofs = bucket*bucketSize;	

	masking4(input0[ofs+lId], ofs+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+256+lId], ofs+256+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+512+lId], ofs+512+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+768+lId], ofs+768+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+1024+lId], ofs+1024+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1280+lId], ofs+1280+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1536+lId], ofs+1536+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1792+lId], ofs+1792+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+2048+lId], ofs+2048+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2304+lId], ofs+2304+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2560+lId], ofs+2560+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2816+lId], ofs+2816+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+3072+lId], ofs+3072+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3328+lId], ofs+3328+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3584+lId], ofs+3584+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3840+lId], ofs+3840+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+4096+lId], ofs+4096+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4352+lId], ofs+4352+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4608+lId], ofs+4608+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4864+lId], ofs+4864+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+5120+lId], ofs+5120+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5376+lId], ofs+5376+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5632+lId], ofs+5632+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5888+lId], ofs+5888+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+6144+lId], ofs+6144+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6400+lId], ofs+6400+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6656+lId], ofs+6656+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6912+lId], ofs+6912+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+7168+lId], ofs+7168+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7424) < iCNT[0]) masking4(input0[ofs+7424+lId], ofs+7424+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7680) < iCNT[0]) masking4(input0[ofs+7680+lId], ofs+7680+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7936) < iCNT[0]) masking4(input0[ofs+7936+lId], ofs+7936+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	if ((lId + 8192) < iCNT[0]) masking4(input0[ofs+8192+lId], ofs+8192+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 8448) < iCNT[0]) masking4(input0[ofs+8448+lId], ofs+8448+lId, &scratch[0], &tab[0], &iCNT[1], mask);
		
	barrier(CLK_LOCAL_MEM_FENCE);	

	uint inLim = min(iCNT[1], (uint) 1216);

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ownPos = lId;
	uint own = scratch4[ownPos];
	uint othPos = own;
	uint buck, pos;
	uint cnt=0;

	uint8 outputEl;
	
	while (ownPos < inLim) {
		uint addr = (othPos < inLim) ? othPos : ownPos+256;
		uint elem = scratch4[addr];
		
		if (othPos < inLim) {
			outputEl.s0 = scratch0[ownPos] ^ scratch0[othPos];	
			outputEl.s1 = scratch1[ownPos] ^ scratch1[othPos];
			if (outputEl.s1 != 0) {
				buck = (outputEl.s0 >> 12) & 0x1FFF;
				pos = atomic_inc(&outCounter[buck]);

				outputEl.s2 = 0; 	
				outputEl.s3 = 0;

				outputEl.lo = shr_4(outputEl.lo,25); 			// Shift away 25 bits

				outputEl.s2 = scratch5[ownPos]; 
				outputEl.s3 = scratch5[othPos]; 

				if (pos < bucketSize) {
					pos += buck*bucketSize;
					output0[pos] = outputEl.lo;
				}
			}
		} else { 
			own = elem;
			ownPos += 256;
		}

		othPos = elem;
		ownPos = (cnt<40) ? ownPos : inLim;
		cnt++;
	} 
}


__kernel __attribute__((reqd_work_group_size(256, 1, 1))) void round4 (				// Round 4
		__global uint4 * input0,
		__global uint4 * output0,
		__global uint * counters) {
	uint lId = get_local_id(0);
	uint grp = get_group_id(0); 

	uint bucket = grp >> 3;
	uint mask = (grp & 7);

	__local uint scratch[7296];
	
	__local uint * scratch0 = &scratch[0];
	__local uint * scratch1 = &scratch[1216];
	__local uint * scratch2 = &scratch[2432];
	__local uint * scratch3 = &scratch[3648];
	__local uint * scratch4 = &scratch[4864];
	__local uint * scratch5 = &scratch[6080];

	__local uint tab[512];
	__local uint iCNT[2];

	__global uint * inCounter = &counters[24576];
	__global uint * outCounter = &counters[32768];

	if (lId == 0) {
		iCNT[1] = 0;
		iCNT[0] = min(inCounter[bucket],(uint) bucketSize);
	} 

	tab[lId] = 0xFFF;
	tab[lId+256] = 0xFFF;

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ofs = bucket*bucketSize;	

	masking4(input0[ofs+lId], ofs+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+256+lId], ofs+256+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+512+lId], ofs+512+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+768+lId], ofs+768+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+1024+lId], ofs+1024+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1280+lId], ofs+1280+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1536+lId], ofs+1536+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+1792+lId], ofs+1792+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+2048+lId], ofs+2048+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2304+lId], ofs+2304+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2560+lId], ofs+2560+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+2816+lId], ofs+2816+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+3072+lId], ofs+3072+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3328+lId], ofs+3328+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3584+lId], ofs+3584+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+3840+lId], ofs+3840+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+4096+lId], ofs+4096+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4352+lId], ofs+4352+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4608+lId], ofs+4608+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+4864+lId], ofs+4864+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+5120+lId], ofs+5120+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5376+lId], ofs+5376+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5632+lId], ofs+5632+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+5888+lId], ofs+5888+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+6144+lId], ofs+6144+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6400+lId], ofs+6400+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6656+lId], ofs+6656+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+6912+lId], ofs+6912+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	masking4(input0[ofs+7168+lId], ofs+7168+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	masking4(input0[ofs+7424+lId], ofs+7424+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7680) < iCNT[0]) masking4(input0[ofs+7680+lId], ofs+7680+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 7936) < iCNT[0]) masking4(input0[ofs+7936+lId], ofs+7936+lId, &scratch[0], &tab[0], &iCNT[1], mask);

	if ((lId + 8192) < iCNT[0]) masking4(input0[ofs+8192+lId], ofs+8192+lId, &scratch[0], &tab[0], &iCNT[1], mask);
	if ((lId + 8448) < iCNT[0]) masking4(input0[ofs+8448+lId], ofs+8448+lId, &scratch[0], &tab[0], &iCNT[1], mask);
		
	barrier(CLK_LOCAL_MEM_FENCE);	

	uint inLim = min(iCNT[1], (uint) 1216);

	barrier(CLK_LOCAL_MEM_FENCE);

	uint ownPos = lId;
	uint own = scratch4[ownPos];
	uint othPos = own;
	uint buck, pos;
	uint cnt=0;

	uint2 outputEl;
	
	while (ownPos < inLim) {
		uint addr = (othPos < inLim) ? othPos : ownPos+256;
		uint elem = scratch4[addr];
		
		if (othPos < inLim) {
			outputEl.s0 = scratch0[ownPos] ^ scratch0[othPos];	
			outputEl.s1 = scratch1[ownPos] ^ scratch1[othPos];
			if ((outputEl.s0 == 0) && (outputEl.s1 == 0)) {			// Last round we want all bits to vanish
				uint4 index;
				index.s0 = scratch2[ownPos];
				index.s1 = scratch3[ownPos];
				index.s2 = scratch2[othPos];
				index.s3 = scratch3[othPos];

				bool ok = true;
				ok = ok && (index.s0 != index.s1) && (index.s0 != index.s2) && (index.s0 != index.s3);
				ok = ok && (index.s1 != index.s2) && (index.s1 != index.s3) && (index.s2 != index.s3);	

				if (ok) {
					pos = atomic_inc(&outCounter[0]);
					if (pos < 256) {
						output0[pos] = index;
					}
				}
			}
		} else { 
			own = elem;
			ownPos += 256;
		}

		othPos = elem;
		ownPos = (cnt<40) ? ownPos : inLim;
		cnt++;
	} 
}


__kernel __attribute__((reqd_work_group_size(16, 1, 1))) void combine (				// Combination round
		__global uint4 * inputR2,
		__global uint4 * inputR1,
		__global uint4 * inputR3,
		__global uint  * inputR0,		
		__global uint4 * inputR4,
		__global uint * counters,
		__global uint4 * results) {

	 uint gId = get_group_id(0);
	uint lId = get_local_id(0);

	__global uint * inCounter = &counters[32768];
	__global uint * outCounters = (__global uint*) &results[0];

	__local uint scratch0[16];
	__local uint scratch1[16];
	__local uint ok[1];

	if (gId < inCounter[0]) {
		if (lId == 0) {
			ok[0] = 0;

			uint4 tmp;
			tmp = inputR4[gId];
			
			scratch1[4*lId+0] = tmp.s0;
			scratch1[4*lId+1] = tmp.s1;
			scratch1[4*lId+2] = tmp.s2;
			scratch1[4*lId+3] = tmp.s3;
		}

		barrier(CLK_LOCAL_MEM_FENCE); 

		if (lId < 4) {								// Read the output of Round 2
			uint addr = scratch1[lId];
			if (addr < (bucketSize << 13)) {
				uint4 tmp = inputR2[addr];
				
				scratch0[2*lId] = tmp.s2;	
				scratch0[2*lId+1] = tmp.s3;	
			}
		}

		barrier(CLK_LOCAL_MEM_FENCE); 

		if (lId < 8) {								// Read the output of Round 1
			uint addr = scratch0[lId];
			if (addr < (bucketSize << 13)) {
				uint4 tmp = inputR1[addr];

				tmp.s0 = tmp.s3 & 0x3FFF;				// Unpack the representation
				tmp.s1 = (tmp.s3 >> 14) & 0x3FFF;

				tmp.s2 = tmp.s2 >> 23;
				tmp.s3 = tmp.s3 >> 28;

				tmp.s3 |= (tmp.s2 << 4);
				tmp.s3 *= bucketSize;
				
				scratch1[2*lId]   = tmp.s0 + tmp.s3;	
				scratch1[2*lId+1] = tmp.s1 + tmp.s3;	
			} 
		}

		barrier(CLK_LOCAL_MEM_FENCE); 	

										
		uint addr = scratch1[lId];					// Read the output of Round 0
		if (addr < (bucketSize << 13)) {
			scratch0[lId] = inputR0[addr];	
		} 

		barrier(CLK_LOCAL_MEM_FENCE); 					// Check for doublicate entries

		for (uint i=0; i<16; i++) {
			if (scratch0[lId] == scratch0[i])   atomic_inc(&ok[0]);
		}
		
		barrier(CLK_LOCAL_MEM_FENCE);

		if (ok[0] == 16) {						// Only entry to itself may be equal
			uint addr;
			if (lId == 0) addr = atomic_inc(&outCounters[0]);	

			uint2 elem;

			if (lId < 8) {
				elem.s0 = scratch0[2*lId];
				elem.s1 = scratch0[2*lId+1];

				if (elem.s0 > elem.s1) elem.s01 = elem.s10;

				scratch1[2*lId] = elem.s0;
				scratch1[2*lId+1] = elem.s1;				// Elements sorted by 2 Elem
			}

			barrier(CLK_LOCAL_MEM_FENCE);				// Do the Equihash element sorting

			uint2 tmp2;
		
			if (lId < 8) {
				tmp2.s0 = lId >> 1;
				tmp2.s1 = (scratch1[4*tmp2.s0+0] > scratch1[4*tmp2.s0+2]) ? (lId ^ 0x1) : lId;

				scratch0[2*lId]   = scratch1[2*tmp2.s1];
				scratch0[2*lId+1] = scratch1[2*tmp2.s1+1];		// Elements sorted by 4 Elem
			}
			
			barrier(CLK_LOCAL_MEM_FENCE);
			
			if (lId < 8) {
				tmp2.s0 = lId >> 2;
				tmp2.s1 = (scratch0[8*tmp2.s0+0] > scratch0[8*tmp2.s0+4]) ? (lId ^ 0x2) : lId;

				scratch1[2*lId+0] = scratch0[2*tmp2.s1+0];		// Elements sorted by 8 Elem
				scratch1[2*lId+1] = scratch0[2*tmp2.s1+1];
			}
		
			barrier(CLK_LOCAL_MEM_FENCE);
			
			if (lId < 8) {
				tmp2.s0 = lId >> 3;
				tmp2.s1 = (scratch1[16*tmp2.s0+0] > scratch1[16*tmp2.s0+8]) ? (lId ^ 0x4) : lId;

				scratch0[2*lId+0] = scratch1[2*tmp2.s1+0];		// Elements sorted by 16 Elem
				scratch0[2*lId+1] = scratch1[2*tmp2.s1+1];
			}
		
			barrier(CLK_LOCAL_MEM_FENCE);					// All Elements sorted	
			
			if (lId == 0) scratch1[0] = addr;

			barrier(CLK_LOCAL_MEM_FENCE);

			addr = scratch1[0];

			if ((addr < 20) && (lId < 4)) {
				uint4 tmp;
				tmp.s0 = scratch0[4*lId];
				tmp.s1 = scratch0[4*lId+1];
				tmp.s2 = scratch0[4*lId+2];
				tmp.s3 = scratch0[4*lId+3];

				results[1 + 4*addr + lId] = tmp;
			}
			
		} 
	}  
}
