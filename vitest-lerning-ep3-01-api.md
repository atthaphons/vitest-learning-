# EP.3 / 1 — `api.spec.ts` ชั้นยิง HTTP

> เอกสารชุด **Vitest Learning EP.3** — 1 ไฟล์เทส = 1 เอกสาร
> ไฟล์ที่อธิบายในเล่มนี้: `frontend/test/app/master/WPEF1121CostCenterMaster/api.spec.ts`
> จำนวน test case: **10** · ระดับความยาก: **★**
>
> ดูภาพรวมทั้งโฟลเดอร์และลำดับการอ่านได้ที่ [00-overview](vitest-lerning-ep3-00-overview.md)

---

# ส่วนที่ 1: `api.spec.ts` — ชั้นยิง HTTP

## 1.1 mock อะไร และทำไม

```ts
vi.mock('@/data/api.util', () => ({
    APIUtil: {
        getRequest: vi.fn(),
        postRequest: vi.fn(),
        putRequest: vi.fn(),
        patchRequest: vi.fn(),
    },
}));

import { APIUtil } from '@/data/api.util';
import { API } from '@/features/master/cost-center-master/api';
```

ไฟล์ `api.ts` ของจอนี้มีหน้าที่เดียว: **แปลง "ชื่อฟังก์ชัน + พารามิเตอร์" → "URL + method + body"**
แล้วส่งต่อให้ `APIUtil` เป็นคนยิงจริง

เทสไฟล์นี้จึง mock `APIUtil` ทิ้ง (ไม่ยิง network จริงเลย) แล้วดักดูว่า
**"ถูกเรียกด้วย URL อะไร"** เท่านั้น

> `vi.fn()` คือ "ฟังก์ชันปลอมที่จำได้ว่าถูกเรียกด้วยอะไรบ้าง"
> เรียกว่า **spy** — เอาไว้ตรวจย้อนหลังด้วย `expect(...).toHaveBeenCalledWith(...)`

> **สำคัญ**: `vi.mock(...)` ต้องเขียน**ก่อน** `import` ที่ใช้ของนั้นเสมอ
> (Vitest จะ hoist `vi.mock` ขึ้นบนสุดให้อัตโนมัติ แต่เขียนเรียงแบบนี้อ่านง่ายกว่า)

```ts
afterEach(() => vi.clearAllMocks());
```
ล้างประวัติการเรียกหลังจบทุกเทส ไม่ให้จำนวนครั้งของเทสก่อนหน้ามาปนกับเทสถัดไป

---

## 1.2 Test Case ทีละตัว

### TC-API-001 ถึง TC-API-004 — dropdown พื้นฐาน 4 ตัว

```ts
it('TC-API-001: getDropdownPlant calls APIUtil.getRequest with correct URL', () => {
    (APIUtil.getRequest as Mock).mockResolvedValue({ data: [] });

    API.getDropdownPlant();

    expect(APIUtil.getRequest).toHaveBeenCalledWith('/common/dropdown/plant');
});
```

อีก 3 ตัวหน้าตาเหมือนกันเป๊ะ ต่างแค่ URL:

| TC | ฟังก์ชัน | URL ที่คาดหวัง |
|---|---|---|
| TC-API-001 | `getDropdownPlant()` | `/common/dropdown/plant` |
| TC-API-002 | `getDropdownShop()` | `/common/dropdown/shop` |
| TC-API-003 | `getDropdownShift()` | `/common/dropdown/shift` |
| TC-API-004 | `getDropdownDepartment()` | `/common/dropdown/department` |

**เช็คอะไร**: URL สะกดถูกไหม — ฟังดูเล็กน้อยแต่เป็นบั๊กที่เจอบ่อยที่สุดเวลา copy-paste
ฟังก์ชันเดิมมาแก้ (เช่น copy `plant` มาทำ `shop` แล้วลืมแก้ URL) ซึ่ง TypeScript
**จับไม่ได้** เพราะ string ยังไง compile ผ่านหมด

> สังเกตว่าเทสพวกนี้**ไม่ `await`** เพราะไม่สนใจค่าที่คืนกลับมา สนใจแค่ว่า
> "ตอนเรียก ส่ง URL อะไรไป" ซึ่งเกิดขึ้นทันทีแบบ synchronous

> `mockResolvedValue({ data: [] })` ใส่ไว้กันไม่ให้ฟังก์ชันพังตอนพยายามอ่านผลลัพธ์
> จาก mock ที่คืน `undefined`

---

### TC-API-005 — URL ที่มี query parameter

```ts
it('TC-API-005: getDropdownMaintainDepartment calls APIUtil.getRequest with plant query param', () => {
    (APIUtil.getRequest as Mock).mockResolvedValue({ data: [] });

    API.getDropdownMaintainDepartment('FBA');

    expect(APIUtil.getRequest).toHaveBeenCalledWith('/master/cost-center/dropdown/maintain-department?plant=FBA');
});
```

**เช็คอะไร**: ส่ง `'FBA'` เข้าไป → ต้องกลายเป็น `?plant=FBA` ต่อท้าย URL
(เช็คทั้งชื่อ key `plant` และตำแหน่ง `?`)

---

### TC-API-006 — query parameter 2 ตัว ต่อด้วย `&`

```ts
it('TC-API-006: getDropdownMaintainShop calls APIUtil.getRequest with plant and department query params', () => {
    API.getDropdownMaintainShop('FBA', '10');

    expect(APIUtil.getRequest).toHaveBeenCalledWith('/master/cost-center/dropdown/maintain-shop?plant=FBA&department=10');
});
```

**เช็คอะไร**: พารามิเตอร์ตัวที่ 2 ต้องต่อด้วย `&` ไม่ใช่ `?` ซ้ำ
(บั๊กคลาสสิกคือเขียน `?plant=FBA?department=10` ซึ่ง server จะอ่าน department ไม่เจอ)

---

### TC-API-007 — ต้อง URL-encode ค่าที่มีอักขระพิเศษ ⭐

```ts
it('TC-API-007: getDropdownMaintainShop URL-encodes plant/department values', () => {
    API.getDropdownMaintainShop('F B', 'A&B');

    expect(APIUtil.getRequest).toHaveBeenCalledWith('/master/cost-center/dropdown/maintain-shop?plant=F%20B&department=A%26B');
});
```

**เช็คอะไร**: นี่คือเทสที่ "มีค่าที่สุด" ในไฟล์นี้ —
- ช่องว่าง ` ` ต้องกลายเป็น `%20`
- เครื่องหมาย `&` ต้องกลายเป็น `%26`

**ทำไมสำคัญ**: ถ้าไม่ encode แล้วค่า department คือ `'A&B'` URL จะกลายเป็น
`?plant=F B&department=A&B` ซึ่ง server จะอ่านว่ามี parameter 3 ตัว
(`plant`, `department=A`, `B`) → ค้นหาผิดทันที และเป็นบั๊กที่**หายากมาก**
เพราะเกิดเฉพาะกับข้อมูลบางแถวเท่านั้น

> แปลว่าในโค้ดจริงต้องมี `encodeURIComponent(plant)` อยู่ ถ้าใครเผลอลบทิ้ง
> เทสตัวนี้จะแดงทันที

---

### TC-API-008 ถึง TC-API-010 — เช็ค HTTP method ให้ถูกตัว

```ts
it('TC-API-008: search calls APIUtil.postRequest with the search criteria body', () => {
    const criteria = { costCenter: 'FBA1' };
    API.search(criteria);
    expect(APIUtil.postRequest).toHaveBeenCalledWith('/master/cost-center', criteria);
});

it('TC-API-009: saveAdd calls APIUtil.putRequest with the add payload', () => {
    const body = { costCenter: 'FBA1A100' };
    API.saveAdd(body as any);
    expect(APIUtil.putRequest).toHaveBeenCalledWith('/master/cost-center', body);
});

it('TC-API-010: saveEdit calls APIUtil.patchRequest with the edit payload', () => {
    const body = { id: 101 };
    API.saveEdit(body as any);
    expect(APIUtil.patchRequest).toHaveBeenCalledWith('/master/cost-center', body);
});
```

**เช็คอะไร**: ทั้ง 3 ตัวยิงไป URL **เดียวกัน** (`/master/cost-center`)
ต่างกันแค่ **method** — จุดนี้แหละที่ต้องเทส:

| TC | ฟังก์ชัน | method | ความหมายในระบบนี้ |
|---|---|---|---|
| TC-API-008 | `search` | `POST` | ค้นหา (ใช้ POST เพราะ criteria ยาวเกินใส่ใน URL) |
| TC-API-009 | `saveAdd` | `PUT` | เพิ่มข้อมูลใหม่ |
| TC-API-010 | `saveEdit` | `PATCH` | แก้ไขข้อมูลเดิม |

ถ้าเผลอสลับ `putRequest` ↔ `patchRequest` → หน้าจอจะกด Save แล้วขึ้น error
`405 Method Not Allowed` ซึ่งงงมากเวลา debug เพราะ URL ก็ถูก body ก็ถูก

---

## 1.3 สรุปส่วนที่ 1

| เทคนิคที่เรียนได้ | ใช้ยังไง |
|---|---|
| `vi.mock('module', factory)` | แทนที่ทั้ง module ด้วยของปลอม |
| `vi.fn()` | ฟังก์ชันปลอมที่จำการถูกเรียก |
| `toHaveBeenCalledWith(...)` | ตรวจว่า "ถูกเรียกด้วยอาร์กิวเมนต์นี้" |
| `mockResolvedValue(x)` | ให้ mock คืน Promise ที่ resolve เป็น `x` |
| `afterEach(() => vi.clearAllMocks())` | ล้างประวัติ ไม่ให้เทสปนกัน |

---

