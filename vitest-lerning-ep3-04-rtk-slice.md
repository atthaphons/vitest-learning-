# EP.3 / 4 — `rtk/slice.spec.ts` Redux state

> เอกสารชุด **Vitest Learning EP.3** — 1 ไฟล์เทส = 1 เอกสาร
> ไฟล์ที่อธิบายในเล่มนี้: `frontend/test/app/master/WPEF1121CostCenterMaster/rtk/slice.spec.ts`
> จำนวน test case: **34** · ระดับความยาก: **★★★**
>
> ดูภาพรวมทั้งโฟลเดอร์และลำดับการอ่านได้ที่ [00-overview](vitest-lerning-ep3-00-overview.md)

---

# ส่วนที่ 4: `rtk/slice.spec.ts` — ทดสอบ Redux state

## 4.1 Redux Toolkit slice คืออะไร (ฉบับย่อ)

`slice` คือที่เก็บ **"สถานะทั้งหมดของหน้าจอ"** ไว้ที่เดียว (screenMode, criteria,
ข้อมูลในตาราง, ตัวเลือก dropdown, หน้าที่กำลังดู ฯลฯ) พร้อมฟังก์ชันสำหรับแก้สถานะนั้น

มี 2 ประเภท:

| ประเภท | ชื่อขึ้นต้น | ทำงานยังไง | ตัวอย่าง |
|---|---|---|---|
| **reducer** (sync) | `rxSet...`, `rxClear...` | แก้ state ทันที | `rxSetScreenMode('SEARCH')` |
| **thunk** (async) | `rxLoad...`, `rxSearch...` | ยิง API ก่อน แล้วค่อยแก้ state | `rxLoadDropdownPlant()` |

### setup ของไฟล์

```ts
vi.mock('@/features/master/cost-center-master/api');
const MockAPI = API as Mocked<typeof API>;

const buildStore = () =>
    configureStore({
        reducer: { wpef1121CostCenterMasterReducer: reducer },
        middleware: (getDefaultMiddleware) => getDefaultMiddleware({ serializableCheck: false }),
    });
```

- `vi.mock('...api')` แบบ**ไม่ใส่ factory** = Vitest สร้าง mock อัตโนมัติให้ทุกฟังก์ชันใน module
  (auto-mock) — สั้นกว่าเขียน `{ search: vi.fn(), ... }` เองทีละตัว
- `buildStore()` สร้าง Redux store **ใหม่สดทุกเทส** — สำคัญมาก เพราะถ้าใช้ store ร่วมกัน
  state ที่เทสก่อนหน้าแก้ไว้จะไหลมาเทสถัดไป → เทสพังแบบสุ่ม (flaky)
- `serializableCheck: false` ปิดคำเตือนของ Redux เรื่องการเก็บ `Date` object ใน state

---

## 4.2 กลุ่ม `initial state` — ค่าตั้งต้นต้องถูก

### TC-INIT-001 — ตรวจค่าเริ่มต้นทุกตัว

```ts
it('TC-INIT-001: has correct default values', () => {
    const store = buildStore();
    const state = store.getState().wpef1121CostCenterMasterReducer;

    expect(state.screenMode).toBe(AppConstants.SCREEN_MODE.INIT);
    expect(state.criteria.plant).toEqual([]);         // multi-select → array ว่าง
    expect(state.criteria.costCenter).toBe('');       // ช่องพิมพ์ → string ว่าง
    expect(state.criteria.effectiveFrom).toBeNull();  // วันที่ → null
    expect(state.dropdown.plant).toHaveLength(0);
    expect(state.dropdown.maintainDepartment).toEqual([
        { name: AppConstants.SELECT_ITEM.SELECT, value: AppConstants.SELECT_ITEM.SELECT },
    ]);
    expect(state.datagrid.data).toHaveLength(0);
    expect(state.datagrid.gridMode).toBe(AppConstants.GRID_MODE.VIEW);
    expect(state.datagrid.paginationModel).toEqual({ page: 0, pageSize: DEFAULT_DATAGRID_PAGE_SIZE });
    expect(state.triggerSearch).toBe(false);
});
```

**เช็คอะไร**: เทสตัวเดียวแต่ยาวที่สุด — ตรวจว่าเปิดหน้าจอมาครั้งแรก ทุกค่าอยู่ในสภาพที่ถูกต้อง

**ทำไมสำคัญ**: initial state คือ "รากฐาน" ของทุกอย่าง ถ้าใครเผลอเปลี่ยน
`criteria.plant` จาก `[]` เป็น `null` → ทุก component ที่เขียน `criteria.plant.map(...)`
จะพังพร้อมกันหมด เทสตัวนี้เป็นด่านแรกที่จะแดง

**จุดที่น่าสนใจที่สุดคือความไม่สมมาตรของ dropdown**:

```ts
expect(state.dropdown.plant).toHaveLength(0);                    // ว่างเปล่า
expect(state.dropdown.maintainDepartment).toEqual([ SELECT ]);   // มี SELECT อยู่ 1 ตัว
```

ในโค้ดจริงมีคอมเมนต์อธิบายไว้:
- `plant`/`shift` มี **ผู้ใช้ 2 คน** — ทั้ง multi-select ของฟอร์มค้นหา (ไม่ต้องการ SELECT)
  และ single-select ในตาราง → จึงเก็บแบบ**ดิบ** ให้แต่ละที่ไปเติมเอง
- `maintainDepartment`/`maintainShop` มี **ผู้ใช้คนเดียว** (single-select ในตาราง)
  → จึงเติม `SELECT` ไว้ใน store เลย ตามแบบแผนเดียวกับจออื่นในระบบ

> บทเรียน: เวลาเจอ assert ที่ดู "ไม่สมมาตร" แบบนี้ ให้ไปหาคอมเมนต์ในโค้ด
> มักมีเหตุผลทางสถาปัตยกรรมซ่อนอยู่เสมอ

---

## 4.3 กลุ่ม `synchronous reducers` — แก้ state ทันที

### TC-SCR-001 / TC-CRT-001 / TC-GRD-001 / TC-GRD-002 — แพทเทิร์นพื้นฐาน

```ts
it('TC-SCR-001: rxSetScreenMode transitions to SEARCH', () => {
    const store = buildStore();
    store.dispatch(rxSetScreenMode(AppConstants.SCREEN_MODE.SEARCH));
    expect(store.getState().wpef1121CostCenterMasterReducer.screenMode).toBe(AppConstants.SCREEN_MODE.SEARCH);
});
```

**แพทเทิร์น 3 บรรทัดที่ใช้ซ้ำทั้งกลุ่มนี้**:
```
1. สร้าง store          const store = buildStore();
2. dispatch action      store.dispatch(rxXxx(ค่า));
3. อ่าน state มาเทียบ    expect(store.getState()....).toBe(ค่า);
```

```ts
it('TC-CRT-001: rxSetSearchCriteria updates criteria fields', () => {
    store.dispatch(rxSetSearchCriteria({ costCenter: 'FBA1', plant: ['FBA'] }));
    expect(state.criteria.costCenter).toBe('FBA1');
    expect(state.criteria.plant).toEqual(['FBA']);
});
```
**เช็คอะไร**: ส่งไปแค่ 2 field ก็แก้แค่ 2 field นั้น (field อื่นต้องไม่หาย) —
เป็นการยืนยันว่า reducer ใช้ `{ ...state.criteria, ...payload }` ไม่ใช่เขียนทับทั้งก้อน

---

### TC-SEL-001 / TC-SEL-002 — เลือกแถวในตาราง

```ts
it('TC-SEL-001: rxSetSelectedRowIds stores and clears selected rows', () => {
    store.dispatch(rxSetSelectedRowIds([3]));
    expect(...selectedRowIds).toEqual([3]);
    store.dispatch(rxSetSelectedRowIds([]));      // ล้างการเลือก
    expect(...selectedRowIds).toEqual([]);
});

it('TC-SEL-002: rxSetSelectedRowIds supports multiple selected rows at once', () => {
    store.dispatch(rxSetSelectedRowIds([3, 5]));
    expect(...selectedRowIds).toEqual([3, 5]);
});
```

**เช็คอะไร**:
- TC-SEL-001 ทดสอบ 2 จังหวะในเทสเดียว: เลือก → ล้าง (กันบั๊กที่ "เลือกได้แต่ยกเลิกไม่ได้")
- TC-SEL-002 ยืนยันว่าเก็บได้**หลายแถว** ทั้งที่ระบบอนุญาตให้ Edit ทีละแถว —
  เพราะ state ต้องเก็บได้ก่อน แล้วค่อยให้**ปุ่ม Edit** เป็นคนบอกว่า "เลือกเกิน 1 ไม่ได้นะ"
  (ดู TC-EDT-002 ใน[06-datagrid](vitest-lerning-ep3-06-datagrid.md))

---

### TC-EDT-001 — เปิดแถวให้แก้ไข

```ts
it('TC-EDT-001: rxSetEditableId stores editable row id and sets rowModesModel', () => {
    store.dispatch(rxSetEditableId(2));
    expect(state.datagrid.editableId).toBe(2);
    expect(state.datagrid.rowModesModel[2]).toBeDefined();
});
```

**เช็คอะไร**: dispatch **ครั้งเดียว** ต้องเกิดผล **2 อย่าง**:
1. `editableId = 2` (state ของเราเอง ใช้ตัดสินใจใน logic)
2. `rowModesModel[2]` ต้องมีค่า — นี่คือ state ที่ **MUI DataGrid** ต้องการ
   เพื่อสั่งให้แถวนั้นเปลี่ยนเป็นโหมดแก้ไข

ถ้าลืมตั้งตัวที่ 2 → state ในหัวเราบอกว่า "กำลัง edit แถว 2" แต่ตารางยังแสดงเป็นข้อความธรรมดา
กดพิมพ์ไม่ได้ — เป็นบั๊กที่สับสนมากเวลาเจอ

---

### TC-CLR-001 — ล้างตาราง แต่ต้อง**ไม่**ล้างหน้าที่ดูอยู่ ⭐

```ts
it('TC-CLR-001: rxClearDataGrid resets datagrid state but keeps paginationModel', () => {
    const store = buildStore();
    store.dispatch(rxSetSelectedRowIds([1]));
    store.dispatch(rxSetEditableId(1));
    store.dispatch(rxSetDataGridMode('EDIT'));
    store.dispatch(rxSetPaginationModel({ page: 1, pageSize: 8 }));

    store.dispatch(rxClearDataGrid());

    const state = store.getState().wpef1121CostCenterMasterReducer.datagrid;
    expect(state.data).toHaveLength(0);
    expect(state.editableId).toBeNull();
    expect(state.rowModesModel).toEqual({});
    expect(state.gridMode).toBe(AppConstants.GRID_MODE.VIEW);
    expect(state.selectedRowIds).toEqual([]);
    expect(state.total).toBe(0);
    expect(state.paginationModel).toEqual({ page: 1, pageSize: 8 });   // ← ต้องคงไว้!
});
```

**เช็คอะไร**: เทสนี้ต่างจากตัวอื่นตรงที่ **dispatch 4 ครั้งเพื่อทำให้ state "รก" ก่อน**
แล้วค่อยล้าง — เพื่อพิสูจน์ว่าการล้างครอบคลุมทุกช่องจริง

**บรรทัดที่สำคัญที่สุดคือบรรทัดสุดท้าย**: `paginationModel` ต้อง**ไม่ถูกล้าง**

ทำไม? ถ้า `rxClearDataGrid` รีเซ็ตหน้ากลับไป 0 ด้วย → user ที่กำลังดูหน้า 3
แล้วกด Cancel จะเด้งกลับหน้า 1 ทุกครั้ง น่ารำคาญมาก
การตัดสินใจว่า "จะกลับหน้า 1 หรือไม่" ถูกแยกไปเป็นหน้าที่ของ `rxResetPagination`
ซึ่งผู้เรียกเป็นคนตัดสินใจเองว่าจะเรียกหรือไม่ (ดู TC-CAN-004 ใน[06-datagrid](vitest-lerning-ep3-06-datagrid.md))

> บทเรียนการออกแบบ: **แยกหน้าที่ให้ชัด** — "ล้างข้อมูล" กับ "รีเซ็ตหน้า"
> เป็นคนละเรื่องกัน อย่ามัดรวมไว้ในฟังก์ชันเดียว

---

### TC-TRG-001 — ธงสั่งค้นหา

```ts
it('TC-TRG-001: rxSetTriggerSearch and rxSetTriggerSearchResetPage toggle flags', () => {
    store.dispatch(rxSetTriggerSearch(true));
    expect(...triggerSearch).toBe(true);
    store.dispatch(rxSetTriggerSearchResetPage(true));
    expect(...triggerSearchResetPage).toBe(true);
});
```

**นี่คืออะไร**: `triggerSearch` เป็น **"ธง" (flag)** ที่ใช้สื่อสารข้าม component —
ฟอร์มค้นหากด Search → ตั้งธงเป็น `true` → ตาราง (คนละ component) เห็นธงแล้วยิงค้นหาเอง
แล้วปิดธงกลับเป็น `false`

มี 2 ธงเพราะต้องแยก 2 กรณี:
- `triggerSearch` — ค้นหาที่หน้าเดิม (เช่น เปลี่ยนหน้า)
- `triggerSearchResetPage` — ค้นหาแล้วกลับไปหน้า 1 (เช่น กด Search ใหม่, Save เสร็จ)

---

### TC-PAG-001 / TC-PAG-002 — จัดการหน้า

```ts
it('TC-PAG-001: rxSetPaginationModel updates page and pageSize', () => {
    store.dispatch(rxSetPaginationModel({ page: 1, pageSize: 8 }));
    expect(...paginationModel).toEqual({ page: 1, pageSize: 8 });
});

it('TC-PAG-002: rxResetPagination resets page to 0 but keeps pageSize', () => {
    store.dispatch(rxSetPaginationModel({ page: 1, pageSize: 8 }));
    store.dispatch(rxResetPagination());
    expect(...paginationModel).toEqual({ page: 0, pageSize: 8 });   // page รีเซ็ต, pageSize คงเดิม
});
```

**เช็คอะไร (TC-PAG-002)**: กลับไปหน้าแรก แต่ **"แสดงกี่แถวต่อหน้า" ต้องคงไว้**
— เพราะนั่นคือค่าที่ user ตั้งใจเลือกเอง ไม่ควรถูกรีเซ็ตโดยระบบ

---

### TC-PAG-003 / TC-PAG-004 — sync ค่า default จาก config ⭐

```ts
it('TC-PAG-003: rxSyncDefaultPageSize updates pagination when the grid still uses the fallback size', () => {
    const store = buildStore();
    store.dispatch(rxSyncDefaultPageSize(25));
    expect(...paginationModel).toEqual({ page: 0, pageSize: 25 });
});

it('TC-PAG-004: rxSyncDefaultPageSize does not clobber a user-selected page size', () => {
    const store = buildStore();
    store.dispatch(rxSetPaginationModel({ page: 3, pageSize: 100 }));   // user เลือกเอง

    store.dispatch(rxSyncDefaultPageSize(25));                          // config มาทีหลัง

    expect(...paginationModel).toEqual({ page: 3, pageSize: 100 });     // ต้องไม่ถูกทับ
});
```

**สถานการณ์จริง**: ค่า "แสดงกี่แถวต่อหน้า" ตั้งได้จากฝั่ง server (config)
แต่ config โหลดแบบ async — อาจมาถึง**หลัง**หน้าจอเปิดไปแล้ว

- TC-PAG-003: ถ้า user ยัง**ไม่เคยแตะ** → เอาค่าจาก config มาใช้ ✅
- TC-PAG-004: ถ้า user **เลือกเองแล้ว** (100 แถว, อยู่หน้า 4) → config ที่มาทีหลัง
  ต้อง**ไม่ทับ** ❌

ถ้าไม่มี TC-PAG-004 จะเกิดบั๊กแบบ "user เลือก 100 แถว แล้วจู่ๆ เด้งกลับเป็น 25 เอง"
ซึ่ง reproduce ยากมากเพราะขึ้นกับว่า config โหลดเสร็จตอนไหน (race condition)

> คำว่า **clobber** ในชื่อเทส = "ทับค่าที่มีอยู่แล้วโดยไม่ตั้งใจ"

---

### TC-MD-001 / TC-MS-001 — ล้าง dropdown แบบ cascade

```ts
it('TC-MD-001: rxClearMaintainDepartment resets maintain-department options back to just the SELECT placeholder', () => {
    const store = buildStore();
    store.dispatch({
        type: rxLoadDropdownMaintainDepartment.fulfilled.type,        // ← ยิง action ตรงๆ
        payload: new RestJsonResponse<NameValue[]>(null, null, mockMaintainDepartmentDropdown),
    });
    expect(...maintainDepartment).toHaveLength(2);                    // SELECT + ตัวเลือกจริง 1

    store.dispatch(rxClearMaintainDepartment());

    expect(...maintainDepartment).toEqual([{ name: SELECT, value: SELECT }]);   // เหลือแค่ SELECT
});
```

**เทคนิคใหม่ที่เห็นครั้งแรก**: `store.dispatch({ type: rxXxx.fulfilled.type, payload })`

แทนที่จะเรียก thunk จริง (ที่ต้อง mock API + `await`) เทสนี้**ยิง action `fulfilled` เข้าไปตรงๆ**
เหมือนบอกว่า *"สมมติว่า API ตอบกลับมาแล้วนะ ด้วยข้อมูลชุดนี้"*

ข้อดี: เร็วกว่า ไม่ต้อง async และโฟกัสเฉพาะ reducer ไม่ปนกับเรื่อง API

**เช็คอะไร**: ทำไมต้องล้าง? เพราะ dropdown พวกนี้เป็นแบบ **cascade** (ลูกโซ่):
เลือก Plant → โหลด Department ของ Plant นั้น → เลือก Department → โหลด Shop

ถ้า user เปลี่ยน Plant ใหม่ ตัวเลือก Department เก่า**ต้องหายทันที**
ไม่งั้น user อาจเลือก Department ที่ไม่มีอยู่ใน Plant ใหม่ → save แล้วพัง

---

## 4.4 กลุ่ม `async thunks` — ยิง API แล้วเก็บผล

```ts
beforeEach(() => vi.clearAllMocks());
```

### TC-DD-001 ถึง TC-DD-004 — โหลด dropdown สำเร็จ

```ts
it('TC-DD-001: rxLoadDropdownPlant.fulfilled stores plant options as-is (no SELECT/ALL prepended)', async () => {
    MockAPI.getDropdownPlant.mockResolvedValue(new RestJsonResponse<NameValue[]>(null, null, mockPlantDropdown));
    const store = buildStore();

    await store.dispatch(rxLoadDropdownPlant());      // ← ต้อง await!

    expect(...dropdown.plant).toEqual(mockPlantDropdown);
});
```

**แพทเทิร์นของ thunk test**:
```
1. ตั้งค่าให้ mock API คืนอะไร     MockAPI.xxx.mockResolvedValue(...)
2. await dispatch thunk            await store.dispatch(rxLoadXxx())
3. เช็ค state                      expect(store.getState()...)
```

> **`await` สำคัญมาก** — ถ้าลืม เทสจะเช็ค state ตั้งแต่ API ยังไม่ตอบ
> แล้วแดงแบบงงๆ ว่า "ได้ `[]` แต่คาดหวัง `[{...}]`"

**ชื่อเทสบอกอะไร**: `stores plant options as-is (no SELECT/ALL prepended)`
— ย้ำเรื่องเดียวกับ TC-INIT-001 ว่า plant เก็บแบบดิบ ไม่เติม `SELECT`

อีก 3 ตัว (TC-DD-002/003/004) เหมือนกันเป๊ะ แค่เปลี่ยนเป็น shop/shift/department

---

### TC-DD-005 ถึง TC-DD-008 — โหลด dropdown ไม่สำเร็จ

```ts
it('TC-DD-005: rxLoadDropdownPlant error leaves plant options untouched', async () => {
    MockAPI.getDropdownPlant.mockResolvedValue(new RestJsonResponse<NameValue[]>('ERR001', 'Failed', []));
    const store = buildStore();
    await store.dispatch(rxLoadDropdownPlant());
    expect(...dropdown.plant).toHaveLength(0);
});
```

**เช็คอะไร**: `RestJsonResponse('ERR001', 'Failed', [])` — พารามิเตอร์ตัวแรกคือ
**messageCode** ซึ่งถ้าไม่ใช่ `null` แปลว่า **error**

reducer ต้องอ่าน messageCode ก่อนเสมอ ถ้ามี error ก็**อย่าเอา data ไปใส่ state**

**ทำไมสำคัญ**: ถ้า reducer เขียนแค่ `state.dropdown.plant = action.payload.data;`
โดยไม่เช็ค error → ตอน API พัง data จะเป็น `[]` หรือ `undefined` แล้วไปทับตัวเลือกดีๆ
ที่โหลดสำเร็จก่อนหน้านี้ → dropdown ว่างเปล่าโดยไม่มีคำอธิบาย

---

### TC-MD-002 / TC-MD-003 / TC-MS-002 / TC-MS-003 — dropdown แบบมีเงื่อนไข

```ts
it('TC-MD-002: rxLoadDropdownMaintainDepartment.fulfilled stores SELECT-prefixed options, scoped call receives the plant argument', async () => {
    MockAPI.getDropdownMaintainDepartment.mockResolvedValue(new RestJsonResponse<NameValue[]>(null, null, mockMaintainDepartmentDropdown));
    const store = buildStore();

    await store.dispatch(rxLoadDropdownMaintainDepartment('FBA'));

    expect(MockAPI.getDropdownMaintainDepartment).toHaveBeenCalledWith('FBA');   // ① ส่ง arg ถูก
    expect(...dropdown.maintainDepartment).toEqual([
        { name: SELECT, value: SELECT },                                         // ② เติม SELECT
        ...mockMaintainDepartmentDropdown,
    ]);
});
```

**เช็ค 2 อย่างในเทสเดียว**:
1. thunk ส่ง `'FBA'` ต่อไปให้ API จริงๆ (ไม่ตกหล่นระหว่างทาง)
2. ผลลัพธ์ถูกเติม `SELECT` ไว้หน้าสุดก่อนเก็บ

```ts
it('TC-MS-002: ... scoped call receives plant+department', async () => {
    await store.dispatch(rxLoadDropdownMaintainShop({ plant: 'FBA', department: '10' }));
    expect(MockAPI.getDropdownMaintainShop).toHaveBeenCalledWith('FBA', '10');
});
```

**จุดที่น่าสังเกต**: thunk รับ **object** `{ plant, department }` (เพราะ thunk รับได้แค่
พารามิเตอร์เดียว) แต่ API รับ **2 พารามิเตอร์แยกกัน** — เทสนี้พิสูจน์ว่าการแตก object
ออกเป็น 2 ตัวถูกต้อง และ**เรียงลำดับถูก** (ไม่สลับเป็น `('10', 'FBA')`)

```ts
it('TC-MD-003: rxLoadDropdownMaintainDepartment error resets ... back to just the SELECT placeholder', async () => {
    MockAPI.getDropdownMaintainDepartment.mockResolvedValue(new RestJsonResponse<NameValue[]>('ERR001', 'Failed', []));
    await store.dispatch(rxLoadDropdownMaintainDepartment('FBA'));
    expect(...maintainDepartment).toEqual([{ name: SELECT, value: SELECT }]);
});
```

**ต่างจาก TC-DD-005 ตรงไหน**: dropdown ธรรมดาตอน error → **"ไม่แตะ"** (คงค่าเดิม)
แต่ maintain dropdown ตอน error → **"ล้างให้เหลือแค่ SELECT"**

เพราะ maintain dropdown ผูกกับ Plant ที่เลือกอยู่ ถ้าโหลดไม่ได้ก็ต้องล้าง
ไม่งั้น user จะเห็นตัวเลือกของ Plant **เก่า** ค้างอยู่ แล้วเลือกผิด

---

### TC-SCH-001 — เปลี่ยน id จาก DB เป็น id ประจำหน้า ⭐⭐

```ts
const mockSearchRows: CostCenterApiRow[] = [
    { id: 101, costCenter: 'FBA1A100', ... },   // id = 101 คือ ID จริงใน database
    { id: 102, costCenter: 'FBA1A100', ... },
];

it('TC-SCH-001: rxSearchCostCenterMaster.fulfilled assigns page-local ids while preserving the real costCenterId', async () => {
    const response = new RestJsonResponse<SearchCostCenterMasterResponse>(null, null, { rows: mockSearchRows, total: 2 });
    MockAPI.search.mockResolvedValue(response);

    const store = buildStore();
    await store.dispatch(rxSearchCostCenterMaster({ costCenter: 'FBA1A100' }));

    const rows = store.getState().wpef1121CostCenterMasterReducer.datagrid.data;
    expect(rows[0].id).toBe(1);             // ← id ในตาราง = ลำดับที่ 1
    expect(rows[0].costCenterId).toBe(101); // ← ID จริงถูกย้ายมาเก็บที่นี่
    expect(rows[1].id).toBe(2);
    expect(rows[1].costCenterId).toBe(102);
    expect(...datagrid.total).toBe(2);
});
```

**นี่คือ logic ที่สำคัญที่สุดของ slice นี้** — มี id 2 ชุดในระบบ:

| field | ค่า | ใช้ทำอะไร |
|---|---|---|
| `id` | 1, 2, 3, ... | เลขลำดับในหน้านี้ — ใช้แสดงคอลัมน์ "No." และให้ MUI DataGrid ใช้อ้างแถว |
| `costCenterId` | 101, 102, ... | ID จริงใน database — ใช้ตอนส่งกลับไป save |

**ทำไมต้องแยก**: เพราะคอลัมน์ "No." ต้องเริ่มที่ 1 เสมอทุกหน้า
ถ้าเอา ID จาก DB มาแสดงตรงๆ user จะเห็น "101, 102" แทนที่จะเป็น "1, 2"

**ความเสี่ยงคือความสับสน**: ถ้าเผลอส่ง `id` (= 1) ไป save แทน `costCenterId` (= 101)
→ จะไปแก้ข้อมูลผิดแถวใน database ซึ่งเป็นบั๊กร้ายแรงมาก
เทสตัวนี้กับ TC-SAV-006 ([06-datagrid](vitest-lerning-ep3-06-datagrid.md)) คือคู่ที่ป้องกันเรื่องนี้

---

### TC-SCH-002 / TC-SCH-005 — เลขลำดับต้องเริ่มที่ 1 ทุกหน้า

```ts
it('TC-SCH-005: rxSearchCostCenterMaster page-local ids run 1..N on a non-first page, never continuing the previous page\'s count', async () => {
    const response = new RestJsonResponse(null, null, { rows: mockSearchRows, total: 10 });
    MockAPI.search.mockResolvedValue(response);

    const store = buildStore();
    store.dispatch(rxSetPaginationModel({ page: 1, pageSize: 8 }));   // อยู่หน้า 2
    await store.dispatch(rxSearchCostCenterMaster({ page: 1 }));

    const rows = store.getState()....datagrid.data;
    expect(rows[0].id).toBe(1);       // ← ไม่ใช่ 9!
    expect(rows[0].costCenterId).toBe(101);
    expect(rows[1].id).toBe(2);
});
```

**เช็คอะไร**: อยู่หน้า 2 (page=1, pageSize=8) → แถวแรกต้อง id = **1** ไม่ใช่ **9**

**ทำไมสำคัญ**: นี่คือจุดที่นักพัฒนามักเขียนผิดเป็น
`id: page * pageSize + index + 1` (= 9, 10) เพราะคิดว่าเลขลำดับควรต่อเนื่องทั้งชุดผลลัพธ์

แต่ในระบบนี้ **ตั้งใจ**ให้เริ่มที่ 1 ทุกหน้า และถ้าเผลอเปลี่ยนเป็นแบบต่อเนื่อง
จะกระทบมากกว่าแค่ตัวเลขที่แสดง — เพราะ `id` ยังถูกใช้เป็น **key ของ MUI DataGrid**
และเป็นค่าที่เก็บใน `selectedRowIds` ด้วย → การเลือกแถวจะเพี้ยนทันที

TC-SCH-002 ทดสอบเรื่องเดียวกันแต่มีแถวเดียว (กันเคสที่โค้ดบังเอิญถูกเพราะมี 2 แถวพอดี)

---

### TC-SCH-003 / TC-SCH-004 — ผลลัพธ์ว่าง และ error

```ts
it('TC-SCH-003: rxSearchCostCenterMaster empty result stores empty array and total 0', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    await store.dispatch(rxSearchCostCenterMaster({}));
    expect(...datagrid.data).toHaveLength(0);
    expect(...datagrid.total).toBe(0);
});

it('TC-SCH-004: rxSearchCostCenterMaster error (e.g. DATE_RANGE_INVALID) clears datagrid rows and total', async () => {
    const response = new RestJsonResponse('MPEF11205ERR', 'Invalid date range', undefined as any);
    MockAPI.search.mockResolvedValue(response);
    await store.dispatch(rxSearchCostCenterMaster({}));
    expect(...datagrid.data).toHaveLength(0);
    expect(...datagrid.total).toBe(0);
});
```

**TC-SCH-004 มีประเด็นซ่อนอยู่**: `data` เป็น `undefined` (ไม่ใช่แค่ว่าง)

reducer ที่เขียนว่า `state.datagrid.data = action.payload.data.rows;` จะ **throw**
`Cannot read properties of undefined (reading 'rows')` ทันที

เทสนี้จึงบังคับให้ต้องเช็ค messageCode ก่อนแตะ data เสมอ —
และเมื่อ error ต้อง**ล้างตาราง** ไม่ใช่ปล่อยผลลัพธ์เก่าค้างไว้
(ไม่งั้น user จะเห็นข้อมูลเก่าคู่กับข้อความ error แล้วเข้าใจผิดว่าคือผลการค้นหาใหม่)

---

### TC-SCH-006 — race condition: คำตอบเก่ามาช้าต้องไม่ทับคำตอบใหม่ ⭐⭐⭐

```ts
it('TC-SCH-006: an older in-flight search resolving after a newer one does not clobber the newer result', async () => {
    let resolveOlder!: (value: RestJsonResponse<SearchCostCenterMasterResponse>) => void;
    let resolveNewer!: (value: RestJsonResponse<SearchCostCenterMasterResponse>) => void;

    MockAPI.search
        .mockReturnValueOnce(new Promise((resolve) => { resolveOlder = resolve; }))   // เรียกครั้งที่ 1
        .mockReturnValueOnce(new Promise((resolve) => { resolveNewer = resolve; }));  // เรียกครั้งที่ 2

    const store = buildStore();
    const olderDispatch = store.dispatch(rxSearchCostCenterMaster({ costCenter: 'OLD' }));
    const newerDispatch = store.dispatch(rxSearchCostCenterMaster({ costCenter: 'NEW' }));

    // จงใจให้ "คำขอใหม่" ตอบกลับมาก่อน
    resolveNewer(new RestJsonResponse(null, null, { rows: [mockSearchRows[1]], total: 1 }));
    await newerDispatch;

    // แล้ว "คำขอเก่า" ค่อยตอบตามมาทีหลัง
    resolveOlder(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    await olderDispatch;

    const state = store.getState().wpef1121CostCenterMasterReducer.datagrid;
    expect(state.total).toBe(1);                    // ผลของคำขอใหม่ต้องยังอยู่
    expect(state.data).toHaveLength(1);
    expect(state.data[0].costCenterId).toBe(102);
});
```

**นี่คือเทสที่ซับซ้อนที่สุดในไฟล์ ขออธิบายละเอียด**

**ปัญหาในโลกจริง**: การค้นหาถูกยิงได้จากหลายที่ (กดปุ่ม Search, เปลี่ยนหน้า,
Save เสร็จแล้วค้นใหม่อัตโนมัติ) และ**ไม่มีใครยกเลิกคำขอเก่า**

ถ้า user กด Search เร็วๆ 2 ครั้ง แล้ว network ทำให้คำตอบมาสลับลำดับ:

```
เวลา →
 ①  ยิงค้นหา 'OLD'  ────────────────────────────────►  ตอบกลับ (ว่าง)
 ②      ยิงค้นหา 'NEW'  ────────►  ตอบกลับ (1 แถว)
                                    ▲                    ▲
                              หน้าจอแสดง 1 แถว    ถ้าไม่ป้องกัน → ถูกทับเป็นว่าง!
```

user จะเห็นผลลัพธ์**หายไปเฉยๆ** ทั้งที่ข้อมูลมีอยู่ — และ reproduce แทบไม่ได้

**เทสจำลองยังไง**:

```ts
let resolveOlder!: (value) => void;
MockAPI.search.mockReturnValueOnce(new Promise((resolve) => { resolveOlder = resolve; }));
```

บรรทัดนี้คือหัวใจ — สร้าง Promise ที่**ยังไม่ resolve** แล้ว**เก็บปุ่ม `resolve` ไว้ในตัวแปรข้างนอก**
ทำให้เทส "กดปุ่มให้ตอบกลับ" ได้เองตามลำดับที่ต้องการ

> `mockReturnValueOnce(...)` ต่อกัน 2 ครั้ง = "เรียกครั้งแรกคืนอันนี้ ครั้งที่สองคืนอันนั้น"
> ต่างจาก `mockResolvedValue` ที่คืนค่าเดิมทุกครั้ง
>
> `let resolveOlder!: ...` — เครื่องหมาย `!` บอก TypeScript ว่า
> "เชื่อเถอะ ตัวแปรนี้จะมีค่าก่อนถูกใช้แน่นอน"

**โค้ดจริงแก้ปัญหานี้ยังไง**: ดูจาก initial state จะเห็น field ชื่อ `latestSearchRequestId`
— slice จำ ID ของคำขอล่าสุดไว้ แล้วตอนคำตอบกลับมาจะเทียบก่อนว่า
"ID นี้ตรงกับคำขอล่าสุดไหม" ถ้าไม่ตรง = คำตอบเก่า → **ทิ้งไปเลย**

---

### TC-RST-001 — reset ทั้งแอป

```ts
it('TC-RST-001: APP_RESET_ALL resets to initial state', () => {
    const store = buildStore();
    store.dispatch(rxSetScreenMode(AppConstants.SCREEN_MODE.SEARCH));
    store.dispatch(rxSetDataGridMode('ADD'));

    store.dispatch({ type: AppConstants.RTK_ACTION.APP_RESET_ALL });

    const state = store.getState().wpef1121CostCenterMasterReducer;
    expect(state.screenMode).toBe(AppConstants.SCREEN_MODE.INIT);
    expect(state.datagrid.gridMode).toBe(AppConstants.GRID_MODE.VIEW);
});
```

**เช็คอะไร**: `APP_RESET_ALL` เป็น action **กลางของทั้งแอป** (ไม่ใช่ของ slice นี้)
ยิงตอน logout หรือเปลี่ยนหน้าจอ — ทุก slice ต้องฟังและล้างตัวเองกลับค่าเริ่มต้น

ถ้า slice ไหนลืมฟัง → user logout แล้ว login เป็นคนอื่น จะเห็นข้อมูลของคนเก่าค้างอยู่
(ปัญหาด้านความปลอดภัย)

> สังเกตว่า dispatch เป็น object ดิบ `{ type: '...' }` เพราะ action นี้ไม่ได้
> ประกาศไว้ใน slice ของเรา — เราแค่ "ฟัง" มันผ่าน `extraReducers`

---

## 4.5 สรุปส่วนที่ 4

| เทคนิค | ใช้ตอนไหน |
|---|---|
| `configureStore()` ใหม่ทุกเทส | กัน state รั่วข้ามเทส |
| `store.dispatch(action)` → `store.getState()` | แพทเทิร์นพื้นฐานของ reducer test |
| `await store.dispatch(thunk())` | ต้อง `await` เสมอสำหรับ thunk |
| `dispatch({ type: rxXxx.fulfilled.type, payload })` | ข้ามการยิง API ไปทดสอบ reducer ตรงๆ |
| `mockReturnValueOnce` + เก็บ `resolve` ไว้ข้างนอก | ควบคุมลำดับการตอบกลับ (ทดสอบ race condition) |
| `vi.mock('module')` ไม่ใส่ factory | auto-mock ทั้ง module |

---

