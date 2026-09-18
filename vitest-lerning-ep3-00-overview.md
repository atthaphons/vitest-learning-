# Vitest Learning EP.3 — ภาพรวมโฟลเดอร์ WPEF1121CostCenterMaster

> EP.2 อธิบายไฟล์เดียวคือ `search.criteria.spec.tsx` (ฟอร์มค้นหา)
> **EP.3 อธิบายไฟล์ที่เหลือทั้งหมด** โดยแยก **1 ไฟล์เทส = 1 เอกสาร**
>
> เล่มนี้คือสารบัญ + ภาพรวม อ่านเล่มนี้ก่อน แล้วค่อยไล่อ่านตามลำดับข้างล่าง

---

## สารบัญ (เรียงจากง่าย → ยาก)

| # | เอกสาร | ไฟล์เทสที่อธิบาย | `it` | ยากง่าย |
|---|---|---|---|---|
| 1 | [01-api](vitest-lerning-ep3-01-api.md) | `api.spec.ts` | 10 | ★ |
| 2 | [02-eff-util](vitest-lerning-ep3-02-eff-util.md) | `eff.util.spec.ts` | 7 | ★ |
| 3 | [03-validation](vitest-lerning-ep3-03-validation.md) | `validation.schema.spec.ts` | 23 | ★★ |
| 4 | [04-rtk-slice](vitest-lerning-ep3-04-rtk-slice.md) | `rtk/slice.spec.ts` | 34 | ★★★ |
| 5 | [05-page](vitest-lerning-ep3-05-page.md) | `page.spec.tsx` | 7 | ★★ |
| 6 | [06-datagrid](vitest-lerning-ep3-06-datagrid.md) | `datagrid.cost-center-master.spec.tsx` | 35 | ★★★★ |
| — | **EP.2** (เล่มก่อน) | `search.criteria.spec.tsx` | 16 | ★★★ |
| | | **รวม EP.3** | **116** | |

---

## 0. แผนที่โฟลเดอร์ — มีไฟล์อะไรบ้าง ทดสอบชั้นไหน

จอ WPEF1121 (Cost Center Master) แบ่งโค้ดเป็นหลายชั้น และ**แต่ละชั้นมีไฟล์เทสของตัวเอง**

```
frontend/test/app/master/WPEF1121CostCenterMaster/
├── api.spec.ts                        ← ชั้นยิง HTTP (URL ถูกไหม)
├── eff.util.spec.ts                   ← ฟังก์ชันแปลงวันที่ล้วนๆ
├── validation.schema.spec.ts          ← กติกา validate แถวข้อมูล (yup)
├── rtk/slice.spec.ts                  ← Redux state (reducer + thunk)
├── page.spec.tsx                      ← หน้าจอหลัก ประกอบ section
├── search.criteria.spec.tsx           ← ฟอร์มค้นหา  ** อธิบายไว้ใน EP.2 **
└── datagrid.cost-center-master.spec.tsx ← ตาราง Add/Edit/Save/Cancel (ใหญ่สุด)
```

| ไฟล์ | จำนวน `it` | ชั้นที่ทดสอบ | ยากง่าย |
|---|---|---|---|
| `api.spec.ts` | 10 | API layer | ★ ง่ายสุด |
| `eff.util.spec.ts` | 7 (รันจริง 18 รอบ) | pure function | ★ |
| `validation.schema.spec.ts` | 23 | business rule | ★★ |
| `rtk/slice.spec.ts` | 34 | Redux state | ★★★ |
| `page.spec.tsx` | 7 | layout ของหน้า | ★★ |
| `datagrid.cost-center-master.spec.tsx` | 35 | UI + flow เต็มรูปแบบ | ★★★★ ยากสุด |
| **รวม (ไม่นับ EP.2)** | **116** | | |

**แนะนำให้อ่านตามลำดับในเอกสารนี้** เพราะเรียงจากง่าย → ยาก
แต่ละส่วนจะสอนแนวคิดใหม่เพิ่มขึ้นทีละนิด

### พีระมิดการทดสอบ (ทำไมต้องแยกหลายไฟล์)

```
            ▲  น้อย / ช้า / จริงที่สุด
           ╱ ╲        e2e (Playwright)      ← เบราว์เซอร์จริง + DB จริง
          ╱   ╲
         ╱─────╲  component test            ← datagrid, page, search.criteria
        ╱       ╲                              (React จริง แต่ mock API)
       ╱─────────╲ unit test                ← api, eff.util, validation.schema, slice
      ╱___________╲ มาก / เร็ว / แยกส่วนที่สุด
```

กฎง่ายๆ: **อะไรที่เทสได้ในชั้นล่าง อย่าเอาไปเทสชั้นบน** เพราะชั้นล่างรันเร็วกว่า
เป็นร้อยเท่า และพอพังจะชี้จุดผิดได้ตรงกว่ามาก

---

# สรุปรวมทั้งโฟลเดอร์

## 7.1 ตารางสรุปทุกไฟล์

| ไฟล์ | `it` | เนื้อหาหลัก |
|---|---|---|
| `api.spec.ts` | 10 | URL, query param, encoding, HTTP method |
| `eff.util.spec.ts` | 7 | แปลง YYYYMM ↔ Date, จัดการ input เพี้ยน |
| `validation.schema.spec.ts` | 23 | required/maxLength ตาม action, ช่วงวันที่, placeholder SELECT |
| `rtk/slice.spec.ts` | 34 | initial state, reducer, thunk, id mapping, race condition |
| `page.spec.tsx` | 7 | แสดง section ตาม screenMode, sync page size |
| `datagrid.cost-center-master.spec.tsx` | 35 | ปุ่ม, Add/Edit, cascade, Save/Cancel, pagination |
| **รวม** | **116** | |
| `search.criteria.spec.tsx` | 16 | → อธิบายไว้ใน **EP.2** |

## 7.2 แผนที่ความเชื่อมโยง — เรื่องเดียวกันถูกเทสหลายชั้น

นี่คือสิ่งสำคัญที่สุดที่ควรเข้าใจจากเอกสารนี้:

| เรื่อง | ชั้นล่าง (unit) | ชั้นบน (component) | ชั้น e2e |
|---|---|---|---|
| id จริง vs เลขลำดับ | TC-SCH-001/002/005 (slice) | TC-SAV-006 (datagrid) | flow test |
| required/maxLength | TC-VAL-003..023 (schema) | TC-SAV-001/005/008 (datagrid) | — |
| ล้าง cascade dropdown | TC-MD-001, TC-MS-001 (slice) | TC-CAS-004/005/006 (datagrid) | — |
| sync default page size | TC-PAG-003/004 (slice) | TC-PAGE-005/006 (page) | — |
| แก้ effectiveFrom ไม่ได้ | TC-VAL-004/010 (schema) | TC-RO-001 (datagrid) | — |
| dropdown disabled state | — | TC-CAS-001/002 (datagrid, บางส่วน) | Step 32 (ปิดช่องว่าง) |

**อ่านตารางนี้ยังไง**: แต่ละแถวคือ "กติกา 1 ข้อ" ที่ต้องถูกต้องทั้ง 2-3 ชั้น
- ชั้นล่างเทสว่า **"logic ถูกไหม"**
- ชั้นบนเทสว่า **"ถูกเรียกใช้ในจังหวะที่ถูกไหม"**

ขาดชั้นใดชั้นหนึ่งก็ยังมีบั๊กหลุดได้

## 7.3 หลักการที่ใช้ได้กับทุกจอ

1. **แยกไฟล์เทสตามชั้นของโค้ด** — API / util / schema / slice / component คนละไฟล์
2. **เทสชั้นล่างให้ละเอียด ชั้นบนให้เน้น flow** — ไม่เทสกติกา validate ซ้ำใน component
3. **ทุกเทสต้องมีคู่ตรงข้าม** — "ต้อง error" คู่กับ "ต้องไม่ error" เสมอ
4. **ทดสอบที่ขอบ** — max+1, เท่ากันพอดี, ว่าง, null, placeholder
5. **mock เท่าที่จำเป็น และเขียนคอมเมนต์บอกว่าแลกอะไรไป**
6. **ตั้งค่าเริ่มต้นให้ต่างจากผลที่คาดหวัง** เพื่อพิสูจน์ว่าโค้ดทำงานจริง
7. **เทสที่เกิดจากบั๊กจริง (regression) มีค่าที่สุด** — ใส่คอมเมนต์อธิบายที่มาไว้เสมอ
8. **state ใหม่ทุกเทส** — store ใหม่, `clearAllMocks` — ห้ามให้เทสไหลถึงกัน

## 7.4 คำสั่งรันเทส

```bash
# รันทั้งโฟลเดอร์
npx vitest run frontend/test/app/master/WPEF1121CostCenterMaster

# รันไฟล์เดียว
npx vitest run frontend/test/app/master/WPEF1121CostCenterMaster/api.spec.ts

# รันเฉพาะเทสที่ชื่อมีคำนี้ (เช่น TC ตัวเดียว)
npx vitest run frontend/test/app/master/WPEF1121CostCenterMaster -t "TC-SCH-006"

# โหมด watch (แก้โค้ดแล้วรันใหม่อัตโนมัติ)
npx vitest frontend/test/app/master/WPEF1121CostCenterMaster

# ดู coverage
npx vitest run --coverage frontend/test/app/master/WPEF1121CostCenterMaster
```

---

### แหล่งอ้างอิงในโปรเจกต์นี้

- `frontend/test/app/master/WPEF1121CostCenterMaster/` — ไฟล์เทสทั้งหมดที่อธิบายในเอกสารนี้
- `frontend/src/features/master/cost-center-master/` — โค้ดจริงที่ถูกทดสอบ
- **EP.1** — `it.each` คืออะไร
- **EP.2** — อธิบาย `search.criteria.spec.tsx` ทีละ test case
