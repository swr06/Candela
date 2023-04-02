int FindMSB(int x)
{
    int i;
    int mask;
    int res = -1;
    if (x < 0) 
        x = ~x;
    for (i = 0; i < 32; i++) {
        mask = 0x80000000U >> i;
        if (x & mask) {
            res = 31 - i;
            break;
        }
    }
    return res;
}
