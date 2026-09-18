# Vitest Learning EP.1 — `it.each` คืออะไร?

> เอกสารนี้สรุปจากการเรียนรู้จริงในโปรเจกต์ (อ้างอิงไฟล์
> `frontend/test/app/master/WPEF1121CostCenterMaster/search.criteria.spec.tsx`)
> เขียนไว้สำหรับสอนคนที่ไม่มีพื้นฐาน Vitest/Jest มาก่อน

---

## 1. ปัญหาที่เจอ

เวลาเขียน unit test เรามักเจอสถานการณ์แบบนี้: **logic การทดสอบเหมือนกันเป๊ะ
ต่างกันแค่ "ค่าที่ใช้ทดสอบ"**

ตัวอย่างเช่น เราอยากเช็คว่า ปุ่ม Search/Clear ต้อง disable
เมื่อ grid อยู่ในโหมด `ADD` **หรือ** โหมด `EDIT` — สองเคสนี้ทำสิ่งเดียวกัน
ต่างกันแค่ค่า mode ที่ใส่เข้าไป

ถ้าเขียนแบบพื้นฐาน (ไม่ใช้ `it.each`) จะต้องเขียนซ้ำสองก้อน:

```ts
it('disables buttons in ADD mode', async () => {
    const gridMode = AppConstants.GRID_MODE.ADD;
    const store = buildStore({ /* ...ตั้งค่า gridMode... */ });
    renderWithStore(store);

    expect(screen.getByTestId('wpef1121-btn-search')).toBeDisabled();
    expect(screen.getByTestId('wpef1121-btn-clear')).toBeDisabled();
});

it('disables buttons in EDIT mode', async () => {
    const gridMode = AppConstants.GRID_MODE.EDIT; // <- ต่างกันแค่บรรทัดนี้
    const store = buildStore({ /* ...ตั้งค่า gridMode... */ });
    renderWithStore(store);

    expect(screen.getByTestId('wpef1121-btn-search')).toBeDisabled();
    expect(screen.getByTestId('wpef1121-btn-clear')).toBeDisabled();
});
```

**ปัญหา**: โค้ดซ้ำกันเกือบทั้งหมด ถ้าวันหนึ่งต้อง fix logic ในเทส
ต้องมาแก้ทั้งสองที่ เสี่ยงแก้ไม่ครบ/ไม่ตรงกัน

---

## 2. ทางแก้: `it.each`

`it.each` เป็นฟีเจอร์ของ Vitest (และ Jest) ที่ให้เรา **เขียน logic ของเทสแค่ครั้งเดียว
แล้วป้อน "ชุดข้อมูล" หลายชุดเข้าไป ให้มันรันซ้ำอัตโนมัติทีละชุด**

โค้ดจริงจากโปรเจกต์:

```ts
it.each([AppConstants.GRID_MODE.ADD, AppConstants.GRID_MODE.EDIT])(
    'TC-DIS-001: disables Search/Clear buttons while the grid is in %s mode, but keeps criteria inputs enabled',
    async (gridMode) => {
        const initialState = reducer(undefined, { type: '@@INIT' });
        const store = buildStore({
            wpef1121CostCenterMasterReducer: {
                ...initialState,
                datagrid: { ...initialState.datagrid, gridMode },
            },
        });
        renderWithStore(store);

        await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

        expect(screen.getByTestId('wpef1121-btn-search')).toBeDisabled();
        expect(screen.getByTestId('wpef1121-btn-clear')).toBeDisabled();
        expect(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')).toBeEnabled();
    }
);
```

เทสนี้เขียนครั้งเดียว แต่จะ**รัน 2 รอบจริง** — รอบแรกด้วย `gridMode = ADD`,
รอบสองด้วย `gridMode = EDIT`

---

## 3. วิธีอ่าน syntax

```
it.each( [ค่า1, ค่า2, ค่า3] )( 'ชื่อเทส %s', async (พารามิเตอร์) => { ... } )
        └──────┬──────┘       └───┬───┘              └──────┬─────┘
      ชุดข้อมูลที่จะวนรัน      %s = placeholder      ค่าที่ได้รับในแต่ละรอบ
      (มีกี่ตัว = รันกี่รอบ)   ของชื่อในแต่ละรอบ
```

| ส่วนของโค้ด | ความหมาย |
|---|---|
| `[AppConstants.GRID_MODE.ADD, AppConstants.GRID_MODE.EDIT]` | อาร์เรย์ของ "input" ที่จะป้อนให้เทส — มี 2 ค่า จึงรัน 2 รอบ |
| `'...%s mode...'` | ชื่อเทส โดย `%s` จะถูกแทนที่ด้วยค่าของรอบนั้น (รอบแรกได้ `ADD mode`, รอบสองได้ `EDIT mode`) |
| `async (gridMode) => {...}` | ฟังก์ชันทดสอบ รับค่าที่ส่งมาจากอาร์เรย์เป็นพารามิเตอร์ชื่อ `gridMode` |

เวลารัน `vitest` จะเห็นผลลัพธ์แยกเป็น 2 บรรทัดในรายงาน เช่น:

```
✓ TC-DIS-001: disables Search/Clear buttons while the grid is in ADD mode...
✓ TC-DIS-001: disables Search/Clear buttons while the grid is in EDIT mode...
```

---

## 4. ตัวอย่างง่ายๆ สำหรับมือใหม่

### ตัวอย่างที่ 1 — ค่าเดี่ยว (array ธรรมดา)

```ts
it.each([1, 2, 3])('เลข %i ต้องมากกว่า 0', (n) => {
    expect(n).toBeGreaterThan(0);
});
```
รันทั้งหมด 3 รอบ ด้วยค่า `n = 1`, `n = 2`, `n = 3`

### ตัวอย่างที่ 2 — หลายค่าต่อรอบ (array ของ array)

```ts
it.each([
    [1, 1, 2],
    [2, 3, 5],
    [5, 5, 10],
])('add(%i, %i) ต้องได้ %i', (a, b, expected) => {
    expect(a + b).toBe(expected);
});
```
แต่ละแถวในอาร์เรย์ใหญ่ = 1 รอบ ค่าจะถูกแตกเป็นพารามิเตอร์ `a, b, expected` ตามลำดับ

### ตัวอย่างที่ 3 — ใช้ object แทน (อ่านง่ายกว่าเวลามีหลาย field)

```ts
it.each([
    { input: 'hello', expected: 'HELLO' },
    { input: 'world', expected: 'WORLD' },
])('toUpperCase($input) ต้องได้ $expected', ({ input, expected }) => {
    expect(input.toUpperCase()).toBe(expected);
});
```
กรณีนี้ใช้ `$key` แทน `%s`/`%i` เพื่อดึงค่าจาก object มาแสดงในชื่อเทสได้ตรงๆ

---

## 5. Placeholder ที่ใช้บ่อยในชื่อเทส

| Placeholder | ใช้กับ |
|---|---|
| `%s` | string |
| `%i` | integer |
| `%d` | number |
| `%j` | JSON |
| `%#` | index ของรอบ (0, 1, 2, ...) |
| `$key` | ดึงค่าจาก field ของ object โดยตรง (เฉพาะกรณี input เป็น array of objects) |

---

## 6. สรุป

- `it.each` ใช้เมื่อ "เทส logic เดียวกัน แต่ input ต่างกันหลายชุด"
- ช่วยลดโค้ดซ้ำ, ลดความเสี่ยงแก้ไม่ครบทุกเคส
- อ่านผลลัพธ์ตอนรันเทสได้ง่าย เพราะแต่ละชุดข้อมูลจะขึ้นเป็นบรรทัดแยกกันในรายงาน
- ใช้ได้ทั้งกับ `it.each` และ `test.each` (สองคำนี้เป็นคำพ้อง/alias กัน)

---

### แหล่งอ้างอิงในโปรเจกต์นี้

- `frontend/test/app/master/WPEF1121CostCenterMaster/search.criteria.spec.tsx`
  บรรทัด 122-141 (TC-DIS-001) — ตัวอย่างการใช้งานจริงกับ Redux store + React Testing Library
