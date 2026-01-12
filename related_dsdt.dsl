// 52007
    Scope (_SB)
    {
        Name (ATKP, Zero)
        Name (AITM, Zero)
        Name (PLMD, Zero)
        Name (MUTX, One)
        Name (LEDS, Zero)
        Name (FNIV, Zero)
        Name (PDKB, Zero)
        Device (ATKD)
        {
            Name (_HID, "PNP0C14" /* Windows Management Instrumentation Device */)  // _HID: Hardware ID
            Name (_UID, "ATK")  // _UID: Unique ID
            Name (ATKQ, Package (0x10)
            {
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF, 
                0xFFFFFFFF
            })
            Name (AQHI, Zero)
            Name (AQTI, 0x0F)
            Name (AQNO, Zero)
            Method (IANQ, 1, Serialized)
            {
                If ((AQNO >= 0x10))
                {
                    Local0 = 0x64
                    While ((Local0 && (AQNO >= 0x10)))
                    {
                        Local0--
                        Sleep (0x0A)
                    }

                    If ((!Local0 && (AQNO >= 0x10)))
                    {
                        Return (Zero)
                    }
                }

                AQTI++
                AQTI &= 0x0F
                ATKQ [AQTI] = Arg0
                AQNO++
                Return (One)
            }

            Method (GANQ, 0, Serialized)
            {
                If (AQNO)
                {
                    AQNO--
                    Local0 = DerefOf (ATKQ [AQHI])
                    AQHI++
                    AQHI &= 0x0F
                    Return (Local0)
                }

                Return (Ones)
            }

            Name (_WDG, Buffer (0x3C)
            {
                /* 0000 */  0xD0, 0x5E, 0x84, 0x97, 0x6D, 0x4E, 0xDE, 0x11,  // .^..mN..
                /* 0008 */  0x8A, 0x39, 0x08, 0x00, 0x20, 0x0C, 0x9A, 0x66,  // .9.. ..f
                /* 0010 */  0x4E, 0x42, 0x01, 0x02, 0x35, 0xBB, 0x3C, 0x0B,  // NB..5.<.
                /* 0018 */  0xC2, 0xE3, 0xED, 0x45, 0x91, 0xC2, 0x4C, 0x5A,  // ...E..LZ
                /* 0020 */  0x6D, 0x19, 0x5D, 0x1C, 0xFF, 0x00, 0x01, 0x08,  // m.].....
                /* 0028 */  0x21, 0x12, 0x90, 0x05, 0x66, 0xD5, 0xD1, 0x11,  // !...f...
                /* 0030 */  0xB2, 0xF0, 0x00, 0xA0, 0xC9, 0x06, 0x29, 0x10,  // ......).
                /* 0038 */  0x4D, 0x4F, 0x01, 0x00                           // MO..
            })

            ...
// 52283
            Name (MMFG, Zero)
            Method (WMNB, 3, Serialized)
            {
                CreateDWordField (Arg2, Zero, IIA0)
                CreateDWordField (Arg2, 0x04, IIA1)
                CreateDWordField (Arg2, 0x08, IIA2)
                Local0 = (Arg1 & 0xFFFFFFFF)
                ...
// 52399
                If ((Local0 == 0x53545344))
                {
                ...
// 52878
                    If ((IIA0 == 0x00060078))
                    {
                        Local1 = ^^PC00.LPCB.EC0.ST8E (0x50, Zero)
                        If (((Local1 & One) == One))
                        {
                            Local0 = One
                        }
                        ElseIf (((Local1 & 0x02) == 0x02))
                        {
                            Local0 = Zero
                        }

                        If ((FSIS == Zero))
                        {
                            Local0 |= 0x00080000
                        }

                        Local0 |= 0x00050000
                        Local2 = (Local0 & One)
                        SGOV (0x00180885, Local2)
                        Return (Local0)
                        Return (Zero)
                    }

                    If ((IIA0 == 0x00060079))
                    {
                        Return (Zero)
                    }
// 52906
                ...
// 53019
                If ((Local0 == 0x53564544))
                {
                    ...
// 53319
                    If ((IIA0 == 0x00060078))
                    {
                        Local2 = 0xFF
                        If ((IIA1 == 0x02))
                        {
                            If ((FSIS == One))
                            {
                                Return (Zero)
                            }

                            FSIS = One
                            Local1 = ^^PC00.LPCB.EC0.ST8E (0x50, Zero)
                            If (((Local1 & One) == One)) // Camera on
                            {
                                ^^PC00.LPCB.EC0.ST9E (0x50, 0x80, 0xFF)
                                Sleep (0x0A)
                                Local1 = ^^PC00.LPCB.EC0.ST8E (0x50, Zero)
                                If (((Local1 & One) == One))
                                {
                                    Return (Zero)
                                }
                            }

                            Local2 = One
                        }
                        ElseIf ((IIA1 == 0x03))
                        {
                            If ((FSIS == One))
                            {
                                Return (Zero)
                            }

                            FSIS = One
                            Local1 = ^^PC00.LPCB.EC0.ST8E (0x50, Zero)
                            If (((Local1 & 0x02) == 0x02)) // Camera off
                            {
                                Return (Zero)
                            }

                            Local2 = Zero
                        }

                        If ((Local2 == 0xFF))
                        {
                            Return (Zero)
                        }

                        Local2 = ~Local2
                        Local2 &= One
                        SGOV (0x00180885, Local2)
                        Return (One)
                    }

                    If ((IIA0 == 0x00060079))
                    {
                        Return (Zero)
                    }
// 53377
...
// 53514
                Return (0xFFFFFFFE)
            }
