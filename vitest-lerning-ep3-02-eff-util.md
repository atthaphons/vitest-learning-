# EP.3 / 2 — `eff.util.spec.ts` ทดสอบ pure function

> เอกสารชุด **Vitest Learning EP.3** — 1 ไฟล์เทส = 1 เอกสาร
> ไฟล์ที่อธิบายในเล่มนี้: `frontend/test/app/master/WPEF1121CostCenterMaster/eff.util.spec.ts`
> จำนวน test case: **7 (รันจริง 18 รอบ)** · ระดับความยาก: **★**
>
> ดูภาพรวมทั้งโฟลเดอร์และลำดับการอ่านได้ที่ [00-overview](vitest-lerning-ep3-00-overview.md)

---

# ส่วนที่ 2: `eff.util.spec.ts` — ทดสอบ pure function

## 2.1 pure function คืออะไร ทำไมเทสง่ายที่สุด

`EffUtil` คือชุดฟังก์ชันแปลงวันที่ระหว่างรูปแบบ `'202106'` (YYYYMM) กับ `Date`
**ไม่มี** React, ไม่มี Redux, ไม่มี API — ใส่อะไรเข้าไปก็ได้ค่าเดิมออกมาเสมอ

ไฟล์เทสจึงไม่ต้อง mock อะไรเลยสักบรรทัด:

```ts
import { EffUtil } from '@/features/master/cost-center-master/eff.util';
```

จบ — import แล้วเรียกได้เลย นี่คือเหตุผลที่ควร**แยก logic แบบนี้ออกมาเป็นไฟล์ util ต่างหาก**
แทนที่จะฝังไว้ใน component

---

## 2.2 กลุ่ม `toDate` — แปลง `'202106'` → `Date`

### TC-EFF-01 — เคสปกติ

```ts
it('TC-EFF-01: converts a valid YYYYMM string to the first of that month', () => {
    const date = EffUtil.toDate('202106');
    expect(date).toEqual(new Date(2021, 5, 1));
});
```

**เช็คอะไร**: `'202106'` (มิ.ย. 2021) → ต้องได้ `Date` ของ **วันที่ 1** มิ.ย. 2021

> ⚠️ จุดที่มือใหม่พลาดบ่อย: `new Date(2021, 5, 1)` — เลข `5` คือเดือนมิถุนายน
> เพราะ JavaScript นับเดือนเริ่มจาก **0** (ม.ค. = 0, มิ.ย. = 5)
> เทสตัวนี้จึงกันบั๊ก "off-by-one ของเดือน" ซึ่งเป็นบั๊กอมตะของ JS

> ใช้ `toEqual` ไม่ใช่ `toBe` เพราะ `Date` เป็น object —
> `toBe` เทียบว่า "เป็น object ตัวเดียวกันในหน่วยความจำไหม" (ไม่ใช่)
> `toEqual` เทียบ "ค่าข้างในเท่ากันไหม" (ใช่)

---

### TC-EFF-02 — input เพี้ยน 6 แบบ ต้องคืน `null` ทั้งหมด

```ts
it.each([null, undefined, '', '2021-06', '20216', '2021066'])('TC-EFF-02: returns null for %j', (value) => {
    expect(EffUtil.toDate(value)).toBeNull();
});
```

**เช็คอะไร**: `it.each` (ดูรายละเอียดใน **EP.1**) รันซ้ำ 6 รอบด้วย input ที่ผิดคนละแบบ:

| ค่า | ผิดยังไง |
|---|---|
| `null` | ไม่มีค่าเลย |
| `undefined` | ไม่ได้ส่งมา |
| `''` | string ว่าง |
| `'2021-06'` | มีขีดคั่น (รูปแบบผิด) |
| `'20216'` | 5 หลัก (สั้นไป) |
| `'2021066'` | 7 หลัก (ยาวไป) |

ทุกกรณีต้องคืน `null` — **ห้าม throw exception และห้ามคืน `Invalid Date`**
เพราะถ้าคืน `Invalid Date` ออกไป หน้าจอจะแสดงคำว่า `"Invalid Date"` ให้ user เห็น

> `%j` ในชื่อเทสคือ placeholder แบบ JSON ทำให้รายงานผลเทสแสดงเป็น
> `returns null for null`, `returns null for ""`, `returns null for "2021-06"` แยกบรรทัดกัน
> — พอเทสแดงจะรู้ทันทีว่าแดงเพราะ input ตัวไหน

---

## 2.3 กลุ่ม `toYYYYMM` — แปลง `Date` → `'202106'` (ทิศทางกลับกัน)

### TC-EFF-03 — เคสปกติ

```ts
it('TC-EFF-03: converts a Date to a YYYYMM string', () => {
    expect(EffUtil.toYYYYMM(new Date(2021, 5, 15))).toBe('202106');
});
```

**เช็คอะไร**: ใส่ `Date` ของ **วันที่ 15** มิ.ย. 2021 → ได้ `'202106'`

สังเกตว่าตั้งใจใช้วันที่ 15 (ไม่ใช่วันที่ 1) เพื่อพิสูจน์ว่าฟังก์ชัน**ทิ้งส่วนวันไป**
เอาแค่ปี+เดือน — และเลข `5` ต้องกลายเป็น `'06'` (บวก 1 กลับ + เติม 0 ข้างหน้า)

> ครั้งนี้ใช้ `toBe` ได้เพราะผลลัพธ์เป็น string ซึ่งเทียบค่าตรงๆ ได้

---

### TC-EFF-04 / TC-EFF-05 — input ที่ไม่ใช่วันที่ใช้ได้

```ts
it.each([null, undefined])('TC-EFF-04: returns null for %j', (value) => {
    expect(EffUtil.toYYYYMM(value)).toBeNull();
});

it('TC-EFF-05: returns null for an invalid Date', () => {
    expect(EffUtil.toYYYYMM(new Date('not-a-date'))).toBeNull();
});
```

**เช็คอะไร**: TC-EFF-05 น่าสนใจ — `new Date('not-a-date')` **ไม่ error**
แต่สร้าง object `Date` ที่ข้างในเป็น `NaN` (เรียกว่า *Invalid Date*)

ถ้าโค้ดเขียนแค่ `if (!date) return null;` จะ**ดักไม่ได้** เพราะ Invalid Date
ยังเป็น object ที่ truthy อยู่ → ต้องเช็คด้วย `isNaN(date.getTime())` เพิ่ม
เทสตัวนี้คือตัวบังคับให้มีการเช็คนั้น

---

## 2.4 กลุ่ม `formatDisplay` — แปลงเพื่อ**แสดงผล**

### TC-EFF-06

```ts
it('TC-EFF-06: formats a YYYYMM string as MM/yyyy', () => {
    expect(EffUtil.formatDisplay('202106')).toBe('06/2021');
});
```

**เช็คอะไร**: `'202106'` → `'06/2021'` (สลับตำแหน่ง + ใส่ `/`)
นี่คือรูปแบบที่ user เห็นบนตาราง ต่างจากรูปแบบที่เก็บใน DB

### TC-EFF-07

```ts
it.each([null, undefined, '', '2021-06', '20216', '2021066'])('TC-EFF-07: returns null for %j', (value) => {
    expect(EffUtil.formatDisplay(value)).toBeNull();
});
```

ชุด input เพี้ยนชุดเดียวกับ TC-EFF-02 — เพราะ `formatDisplay` ก็รับ YYYYMM เหมือนกัน

---

## 2.5 สรุปส่วนที่ 2

**แพทเทิร์นที่เห็น**: ทุกฟังก์ชันเทสเป็น "คู่" เสมอ
1. **เคสปกติ 1 ตัว** → พิสูจน์ว่าทำงานถูก
2. **เคสเพี้ยนหลายตัวด้วย `it.each`** → พิสูจน์ว่าไม่พังและคืน `null` เสมอ

จำง่ายๆ: **happy path 1 ตัว + unhappy path ให้ครบทุกแบบที่นึกออก**

| เทคนิค | ใช้ยังไง |
|---|---|
| `toEqual` vs `toBe` | object ใช้ `toEqual`, ค่าเดี่ยว (string/number) ใช้ `toBe` |
| `toBeNull()` | เช็คว่าเป็น `null` เป๊ะๆ (ไม่ใช่ `undefined`) |
| `it.each([...])` | ยิง input หลายแบบเข้า logic เดียวกัน |

---

