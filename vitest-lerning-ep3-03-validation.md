# EP.3 / 3 — `validation.schema.spec.ts` กติกาธุรกิจ

> เอกสารชุด **Vitest Learning EP.3** — 1 ไฟล์เทส = 1 เอกสาร
> ไฟล์ที่อธิบายในเล่มนี้: `frontend/test/app/master/WPEF1121CostCenterMaster/validation.schema.spec.ts`
> จำนวน test case: **23** · ระดับความยาก: **★★**
>
> ดูภาพรวมทั้งโฟลเดอร์และลำดับการอ่านได้ที่ [00-overview](vitest-lerning-ep3-00-overview.md)

---

# ส่วนที่ 3: `validation.schema.spec.ts` — ทดสอบกติกาธุรกิจ

## 3.1 โครงสร้างก่อนเข้าเทส

```ts
const i18n = (key: string) => key;
const schema = buildRowValidationSchema(i18n);
```

`buildRowValidationSchema` คืนกติกา validate ของ **1 แถวในตาราง** (เขียนด้วย library `yup`)
มันรับฟังก์ชันแปลภาษาเข้าไป — เทสส่งฟังก์ชันที่ "คืน key ตรงๆ" แทน
เพื่อให้ assert ได้ว่า error ตัวไหนยิง โดยไม่ต้องสนใจข้อความจริง

### ข้อมูลตั้งต้น 2 ชุด

```ts
const validCreateRow: Row = {
    action: 'CREATE',
    effectiveFrom: '202501', effectiveTo: '202506',
    costCenter: 'FBA1A100', lineCode: 'L01', shift: 'W',
    description: 'Group A Line', plant: 'FBA', department: '10', shop: 'ASSY1',
};

const validUpdateRow: Row = {
    action: 'UPDATE',
    effectiveFrom: undefined, effectiveTo: null,   // ← เว้นว่างได้
    costCenter: '', shift: '',                      // ← เว้นว่างได้
    lineCode: 'L02', description: 'Group B Line',
    plant: 'FBA', department: '10', shop: 'ASSY1',
};
```

**หัวใจของไฟล์นี้**: กติกาไม่เหมือนกันระหว่าง `action: 'CREATE'` กับ `'UPDATE'`
- ตอน **CREATE** (เพิ่มแถวใหม่) → ต้องกรอก `effectiveFrom`, `costCenter`, `shift`
- ตอน **UPDATE** (แก้แถวเดิม) → 3 ช่องนั้น**แก้ไม่ได้** (read-only) จึงเว้นว่างได้

> เทคนิคที่ใช้ทั้งไฟล์: เอา row ที่ถูกต้องสมบูรณ์มาเป็นฐาน แล้ว**พังทีละช่อง**
> ด้วย `{ ...validCreateRow, costCenter: '' }` — วิธีนี้ทำให้มั่นใจว่า error ที่เจอ
> มาจากช่องที่เราตั้งใจพังจริงๆ ช่องเดียว

### helper 2 ตัว

```ts
async function validate(row: Row): Promise<yup.ValidationError | null> {
    try {
        await schema.validate(row, { abortEarly: false });
        return null;                       // ผ่านหมด
    } catch (err) {
        return err as yup.ValidationError; // มี error
    }
}

function messages(err: yup.ValidationError): string[] {
    return err.inner.length > 0 ? err.inner.map((e) => e.message) : [err.message];
}
```

- `validate()` — แปลงพฤติกรรมของ yup (โยน exception ตอนไม่ผ่าน) ให้เป็น
  "ผ่าน = `null`, ไม่ผ่าน = object error" ซึ่งเขียน assert ง่ายกว่ามาก
- `abortEarly: false` — บอก yup ว่า **"เจอ error แรกแล้วอย่าเพิ่งหยุด ตรวจให้ครบทุกช่อง"**
  (สำคัญมาก เพราะ user ควรเห็น error ทุกช่องพร้อมกันในครั้งเดียว ไม่ใช่แก้ทีละช่องแล้วกด Save ใหม่)
- `messages()` — ดึงข้อความ error ทั้งหมดออกมาเป็น array ของ string

---

## 3.2 กลุ่มที่ 1 — แถวที่ถูกต้องต้องผ่าน

```ts
it('TC-VAL-001: a fully-filled CREATE row passes validation', async () => {
    expect(await validate(validCreateRow)).toBeNull();
});

it('TC-VAL-002: a fully-filled UPDATE row passes validation, even with CREATE-only fields blank', async () => {
    expect(await validate(validUpdateRow)).toBeNull();
});
```

**เช็คอะไร**: 2 ตัวนี้คือ **"เทสฐาน" (baseline)** ที่สำคัญที่สุดในไฟล์ —
ถ้าเผลอเขียนกติกาเข้มเกินไปจนแถวที่ถูกต้องยังไม่ผ่าน เทส 2 ตัวนี้จะแดงก่อนเพื่อน

และเพราะเทสอื่นทั้งหมดสร้างจาก `{ ...validCreateRow, ช่องที่พัง }`
ถ้าฐานไม่ผ่านตั้งแต่แรก เทสที่เหลือจะ**เชื่อถือไม่ได้ทั้งไฟล์**

---

## 3.3 กลุ่มที่ 2 — `effectiveFrom` / `effectiveTo` (วันที่)

### TC-VAL-003 / TC-VAL-004 — required เฉพาะตอน CREATE

```ts
it('TC-VAL-003: effectiveFrom is required when action is CREATE', async () => {
    const err = await validate({ ...validCreateRow, effectiveFrom: undefined });
    expect(messages(err!)).toContain(`${REQUIRE_FIELD_PREFIX}label.COL_EFFECTIVE_FROM`);
});

it('TC-VAL-004: effectiveFrom is NOT required when action is UPDATE', async () => {
    const err = await validate({ ...validUpdateRow, effectiveFrom: undefined });
    expect(err).toBeNull();
});
```

**เช็คอะไร**: คู่นี้คือแพทเทิร์น **"ต้องกรอก / ไม่ต้องกรอก ขึ้นกับ action"** ที่จะเห็นซ้ำทั้งไฟล์
- CREATE + ไม่กรอก → ต้องมี error `REQUIRE_FIELD_PREFIX + label.COL_EFFECTIVE_FROM`
- UPDATE + ไม่กรอก → ต้อง**ไม่มี** error เลย

**ทำไมต้องเทสทั้งคู่**: ถ้าเทสแค่ TC-VAL-003 ตัวเดียว แล้วมีคนไปเขียน
`effectiveFrom: yup.string().required()` (required เสมอ) เทสก็ยังเขียว
แต่หน้าจอจะพังตอน Edit ทันที — TC-VAL-004 คือตัวจับเคสนั้น

> `toContain(...)` ใช้กับ array = "ใน array นี้ต้องมีสมาชิกตัวนี้อยู่"
> ไม่สนใจว่าจะมีตัวอื่นด้วยหรือไม่ และไม่สนใจลำดับ

---

### TC-VAL-005 / 006 / 007 — ช่วงวันที่ (ขอบเขต)

```ts
it('TC-VAL-005: effectiveTo earlier than effectiveFrom fails the date-range check', async () => {
    const err = await validate({ ...validCreateRow, effectiveFrom: '202506', effectiveTo: '202501' });
    expect(messages(err!)).toContain(`${DATE_RANGE_PREFIX}label.COL_EFFECTIVE_TO|label.COL_EFFECTIVE_FROM`);
});

it('TC-VAL-006: effectiveTo equal to effectiveFrom passes (inclusive range)', async () => {
    const sameMonth = '202503';
    const err = await validate({ ...validCreateRow, effectiveFrom: sameMonth, effectiveTo: sameMonth });
    expect(err).toBeNull();
});

it('TC-VAL-007: effectiveTo left null skips the date-range check entirely', async () => {
    const err = await validate({ ...validCreateRow, effectiveFrom: '202506', effectiveTo: null });
    expect(err).toBeNull();
});
```

**เช็คอะไร**: 3 ตัวนี้คือตัวอย่างคลาสสิกของ **boundary testing** (ทดสอบค่าขอบ):

| TC | From | To | ผลที่ต้องได้ | กันบั๊กอะไร |
|---|---|---|---|---|
| 005 | 202506 | 202501 | ❌ error | To < From ต้องห้าม |
| 006 | 202503 | 202503 | ✅ ผ่าน | เท่ากันต้องได้ (inclusive) |
| 007 | 202506 | `null` | ✅ ผ่าน | ไม่กรอก To = ไม่จำกัดวันสิ้นสุด |

**TC-VAL-006 คือตัวเอกของกลุ่มนี้** — ถ้าคนเขียนโค้ดใช้ `>` แทน `>=`
(เขียน `if (to <= from) error`) เคส "เท่ากัน" จะพังทันที ทั้งที่ในทางธุรกิจ
"มีผลเดือนเดียว" เป็นเรื่องปกติมาก

**TC-VAL-007** กันบั๊กอีกแบบ: ถ้าโค้ดเทียบ `null < '202506'` JavaScript จะแปลง
`null` เป็น `0` แล้วบอกว่า "To น้อยกว่า From" → ขึ้น error ทั้งที่ user แค่ไม่กรอก
ต้องมี guard `if (!effectiveTo) return true;` ก่อนเทียบ

> รูปแบบข้อความ `DATE_RANGE_PREFIX + 'label.COL_EFFECTIVE_TO|label.COL_EFFECTIVE_FROM'`
> ใช้ `|` คั่นเพื่อส่ง "ชื่อ 2 ช่อง" ไปให้ชั้น i18n เอาไปประกอบเป็นประโยค
> เช่น *"Effective To must not be earlier than Effective From"*

---

## 3.4 กลุ่มที่ 3 — ช่องข้อความ (required + maxLength)

### TC-VAL-008 / 009 / 010 — `costCenter`

```ts
it('TC-VAL-008: costCenter is required when action is CREATE', async () => {
    const err = await validate({ ...validCreateRow, costCenter: '' });
    expect(messages(err!)).toContain(`${REQUIRE_FIELD_PREFIX}label.COL_COST_CENTER`);
});

it('TC-VAL-009: costCenter over 8 characters fails max-length on CREATE', async () => {
    const err = await validate({ ...validCreateRow, costCenter: 'FBA1A100X' });   // 9 ตัว
    expect(messages(err!)).toContain(`${EXCEED_MAX_LENGTH_PREFIX}label.COL_COST_CENTER|8`);
});

it('TC-VAL-010: costCenter is NOT required when action is UPDATE', async () => {
    const err = await validate({ ...validUpdateRow, costCenter: '' });
    expect(err).toBeNull();
});
```

**เช็คอะไร**: ครบชุด 3 มุมของช่องเดียว — ว่าง(CREATE), ยาวเกิน, ว่าง(UPDATE)

สังเกต `'FBA1A100X'` = 9 ตัว คือ **max + 1** พอดี — เป็นการทดสอบขอบที่ดี
ถ้าโค้ดเขียน `max(8)` เป็น `max(9)` ผิด เทสจะจับได้ทันที
(ถ้าใช้ 20 ตัวไปเลย จะจับกรณี off-by-one ไม่ได้)

ข้อความ error `...COL_COST_CENTER|8` แนบเลข `8` มาด้วย เพื่อให้ user เห็นว่า
"กรอกได้ไม่เกินกี่ตัว" — เทสจึง assert เลขนี้ด้วย

---

### TC-VAL-011 / 012 — `lineCode` (required เสมอ ทั้ง 2 action)

```ts
it('TC-VAL-011: lineCode is required regardless of action', async () => {
    const err = await validate({ ...validUpdateRow, lineCode: '' });
    expect(messages(err!)).toContain(`${REQUIRE_FIELD_PREFIX}label.COL_LINE_CODE`);
});

it('TC-VAL-012: lineCode over 8 characters fails max-length regardless of action', async () => {
    const err = await validate({ ...validUpdateRow, lineCode: 'L0000002' + 'X' });
    expect(messages(err!)).toContain(`${EXCEED_MAX_LENGTH_PREFIX}label.COL_LINE_CODE|8`);
});
```

**เช็คอะไร**: ต่างจาก `costCenter` ตรงที่ `lineCode` **บังคับกรอกทั้ง CREATE และ UPDATE**
เทสจึงจงใจใช้ `validUpdateRow` เป็นฐาน (ถ้าใช้ `validCreateRow` จะพิสูจน์ไม่ได้ว่า
UPDATE ก็บังคับด้วย)

> `'L0000002' + 'X'` เขียนแบบนี้เพื่อให้เห็นชัดว่า "8 ตัวที่ถูกต้อง + เกินมา 1 ตัว"
> ชัดกว่าเขียน `'L0000002X'` ติดกัน

---

### TC-VAL-015 / 016 — `description` (max 60)

```ts
it('TC-VAL-015: description is required regardless of action', async () => {
    const err = await validate({ ...validUpdateRow, description: '' });
    expect(messages(err!)).toContain(`${REQUIRE_FIELD_PREFIX}label.COL_DESCRIPTION`);
});

it('TC-VAL-016: description over 60 characters fails max-length', async () => {
    const err = await validate({ ...validUpdateRow, description: 'x'.repeat(61) });
    expect(messages(err!)).toContain(`${EXCEED_MAX_LENGTH_PREFIX}label.COL_DESCRIPTION|60`);
});
```

`'x'.repeat(61)` = สร้าง string `'xxx...'` 61 ตัว (= max 60 + 1) — เทคนิคเดียวกับข้างบน
แต่ใช้ `.repeat()` เพราะ 61 ตัวถ้าพิมพ์มือจะนับพลาดแน่นอน

---

## 3.5 กลุ่มที่ 4 — dropdown (ปัญหา placeholder `'SELECT'`) ⭐

นี่คือกลุ่มที่มีบทเรียนซ่อนอยู่มากที่สุด

### TC-VAL-013 / 014 — `shift`

```ts
it('TC-VAL-013: shift is required when action is CREATE', async () => {
    const err = await validate({ ...validCreateRow, shift: '' });
    expect(messages(err!)).toContain(`${REQUIRE_DROPDOWN_FIELD_PREFIX}label.COL_SHIFT`);
});

it('TC-VAL-014: shift left on the "SELECT" placeholder fails even on UPDATE', async () => {
    const err = await validate({ ...validUpdateRow, shift: 'SELECT' });
    expect(messages(err!)).toContain(`${REQUIRE_DROPDOWN_FIELD_PREFIX}label.COL_SHIFT`);
});
```

**หัวใจอยู่ที่ TC-VAL-014**: dropdown ในระบบนี้มีตัวเลือกแรกเป็นคำว่า `'SELECT'`
(แปลว่า "-- กรุณาเลือก --") ซึ่ง**เป็น string ที่มีค่า ไม่ใช่ค่าว่าง**

ถ้าโค้ดเขียนแค่ `.required()` → ค่า `'SELECT'` จะ**ผ่าน** เพราะไม่ใช่ string ว่าง
→ ระบบจะบันทึกคำว่า `"SELECT"` ลง database เป็นชื่อกะจริงๆ 😱

เทสตัวนี้บังคับให้โค้ดต้องมีเงื่อนไขเพิ่ม เช่น
`.test('not-select', v => v !== AppConstants.SELECT_ITEM.SELECT)`

> สังเกต prefix ที่ใช้ต่างจากช่องข้อความ:
> - ช่องพิมพ์ → `REQUIRE_FIELD_PREFIX` (ข้อความประมาณ *"Please enter ..."*)
> - dropdown → `REQUIRE_DROPDOWN_FIELD_PREFIX` (ข้อความประมาณ *"Please select ..."*)
>
> แยก prefix เพราะคำกริยาในภาษาไทย/อังกฤษไม่เหมือนกัน (กรอก vs เลือก)

---

### TC-VAL-017 ถึง TC-VAL-022 — `plant` / `department` / `shop`

```ts
it('TC-VAL-017: plant is always required', async () => {
    const err = await validate({ ...validUpdateRow, plant: '' });
    expect(messages(err!)).toContain(`${REQUIRE_DROPDOWN_FIELD_PREFIX}label.COL_PLANT`);
});

it('TC-VAL-018: plant left on the "SELECT" placeholder is rejected', async () => {
    const err = await validate({ ...validUpdateRow, plant: 'SELECT' });
    expect(messages(err!)).toContain(`${REQUIRE_DROPDOWN_FIELD_PREFIX}label.COL_PLANT`);
});
```

อีก 4 ตัวคือแพทเทิร์นเดียวกันเป๊ะกับอีก 2 ช่อง:

| ช่อง | ว่าง `''` | placeholder `'SELECT'` |
|---|---|---|
| `plant` | TC-VAL-017 | TC-VAL-018 |
| `department` | TC-VAL-019 | TC-VAL-020 |
| `shop` | TC-VAL-021 | TC-VAL-022 |

> **คำถามที่ควรถาม**: 6 เทสนี้เหมือนกันมาก ทำไมไม่ใช้ `it.each` (EP.1)?
> ตอบ: ใช้ก็ได้และจะสั้นลงมาก แต่ทีมเลือกเขียนแยกเพื่อให้ **TC ID แต่ละตัว
> map 1:1 กับเอกสาร test case ของโปรเจกต์** ซึ่งตรวจสอบย้อนกลับง่ายกว่า
> — เป็น trade-off ระหว่าง "โค้ดสั้น" กับ "ตามรอยเอกสารง่าย" ไม่มีคำตอบตายตัว

---

## 3.6 TC-VAL-023 — ต้องรายงาน error ครบทุกช่องในครั้งเดียว ⭐

```ts
it('TC-VAL-023: multiple invalid fields are all reported at once (abortEarly: false)', async () => {
    const err = await validate({
        ...validUpdateRow,
        lineCode: '',
        description: '',
        plant: 'SELECT',
    });
    const msgs = messages(err!);
    expect(msgs).toContain(`${REQUIRE_FIELD_PREFIX}label.COL_LINE_CODE`);
    expect(msgs).toContain(`${REQUIRE_FIELD_PREFIX}label.COL_DESCRIPTION`);
    expect(msgs).toContain(`${REQUIRE_DROPDOWN_FIELD_PREFIX}label.COL_PLANT`);
    expect(msgs).toHaveLength(3);
});
```

**เช็คอะไร**: พังพร้อมกัน 3 ช่อง → ต้องได้ error **3 ข้อความพอดี**

**จุดสำคัญคือ `toHaveLength(3)`** — ไม่ได้เช็คแค่ "มีครบ 3" แต่เช็คว่า **"ไม่เกิน 3"** ด้วย
ซึ่งดักได้ 2 บั๊กพร้อมกัน:

1. **น้อยกว่า 3** → แปลว่า `abortEarly: false` ไม่ทำงาน (หยุดที่ error แรก)
   user จะต้องแก้ทีละช่อง กด Save ใหม่ 3 รอบ — ประสบการณ์ใช้งานแย่มาก
2. **มากกว่า 3** → แปลว่ามีกติกาซ้ำซ้อน ยิง error ช่องเดียวกันหลายรอบ
   user จะเห็นข้อความซ้ำๆ บน banner

> นี่คือตัวอย่างที่ดีของ assert แบบ "ครบและไม่เกิน" — แข็งแรงกว่าการเช็ค `toContain` เฉยๆ มาก

---

## 3.7 สรุปส่วนที่ 3

| แนวคิด | รายละเอียด |
|---|---|
| **baseline test** | ต้องมีเทส "ข้อมูลถูกต้องต้องผ่าน" ก่อนเสมอ (TC-VAL-001/002) |
| **พังทีละช่อง** | `{ ...validRow, ช่องเดียว: ค่าพัง }` ทำให้รู้แน่ว่า error มาจากไหน |
| **เทสเป็นคู่** | มี "ต้อง error" ต้องมี "ต้องไม่ error" คู่กันเสมอ |
| **boundary** | ทดสอบที่ max+1 และที่ค่าเท่ากันพอดี ไม่ใช่ค่ามั่วๆ |
| **placeholder ไม่ใช่ค่าว่าง** | `'SELECT'` ต้องถูก reject แยกจาก `''` |
| **`toHaveLength`** | ปิดช่องโหว่ "เกินมา" ที่ `toContain` จับไม่ได้ |

---

