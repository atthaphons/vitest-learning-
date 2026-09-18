# EP.3 / 6 — `datagrid.cost-center-master.spec.tsx` ตาราง

> เอกสารชุด **Vitest Learning EP.3** — 1 ไฟล์เทส = 1 เอกสาร
> ไฟล์ที่อธิบายในเล่มนี้: `frontend/test/app/master/WPEF1121CostCenterMaster/datagrid.cost-center-master.spec.tsx`
> จำนวน test case: **35** · ระดับความยาก: **★★★★**
>
> ดูภาพรวมทั้งโฟลเดอร์และลำดับการอ่านได้ที่ [00-overview](vitest-lerning-ep3-00-overview.md)

---

# ส่วนที่ 6: `datagrid.cost-center-master.spec.tsx` — ไฟล์ที่ยากที่สุด

## 6.1 ทำไมไฟล์นี้ใหญ่ที่สุด (42 KB, 35 เทส)

เพราะ datagrid คือที่ที่ **flow ทั้งหมดของหน้าจอมาบรรจบกัน**:
ปุ่ม Add/Edit/Save/Cancel, dropdown แบบลูกโซ่, validate, ยิง API, แบ่งหน้า, dialog ยืนยัน

## 6.2 ยุทธศาสตร์การ mock

```ts
vi.mock('@/features/master/cost-center-master/api');       // ไม่ยิง API จริง
vi.mock('@/store/slices/loadingSlice', () => ({ ... }));   // ตัด loading overlay
vi.mock('@/components/BannerNotification', () => ({
    BannerNotificationUtils: {
        show: vi.fn(), showCommonMessage: vi.fn().mockResolvedValue('OK'),
        showServerMessage: vi.fn().mockResolvedValue('OK'),
        showSaveSuccess: vi.fn().mockResolvedValue('OK'),
    },
}));
vi.mock('@/components/ConfirmDialog', () => ({
    ConfirmDialogUtils: {
        showDialogConfirmSave: vi.fn().mockResolvedValue('YES'),        // ← ตอบ YES เป็นค่าเริ่มต้น
        showDialogConfirmCancelChange: vi.fn().mockResolvedValue('YES'),
    },
}));
```

**จุดสำคัญ**: dialog ยืนยันถูก mock ให้ **ตอบ `'YES'` อัตโนมัติ**
เพราะเทสส่วนใหญ่สนใจว่า "กด Save แล้วเกิดอะไรต่อ" ไม่ได้สนใจตัว dialog

เทสที่อยากทดสอบการกดปฏิเสธจะ override เฉพาะเทสนั้น:
```ts
(ConfirmDialogUtils.showDialogConfirmSave as Mock).mockResolvedValueOnce('NO');
```
> `mockResolvedValueOnce` = "ครั้งถัดไปครั้งเดียวคืนค่านี้ แล้วกลับไปใช้ค่าเดิม"
> ทำให้ไม่ต้องรีเซ็ตเองหลังเทสจบ

### การแทน MUI Select/DatePicker ด้วย input ธรรมดา

```ts
vi.mock('@/components/FormSelect', () => ({
    __esModule: true,
    default: ({ testId, items, value, disabled, handleChange }: any) =>
        React.createElement('select',
            { 'data-testid': testId, value: value ?? '', disabled, onChange: (e) => handleChange?.(e, null) },
            (items ?? []).map((item) => React.createElement('option', { key: item.value, value: item.value }, item.name))
        ),
}));
```

MUI Select เปิดเมนูแบบ portal ซึ่งควบคุมยากมากใน jsdom → แทนด้วย `<select>` ธรรมดา
ที่ยังรักษา **"สัญญา" (contract)** เดิมไว้: `testId`, `value`, `disabled`, `handleChange`

**คอมเมนต์ในไฟล์บอกตรงๆ ว่าแลกอะไรไป** (ควรอ่าน — เป็นตัวอย่างการเขียนคอมเมนต์ที่ดีมาก):

> การ mock ด้วย `<select>` ธรรมดาทำให้ `disabled` เป็น attribute จริงของ HTML
> ดังนั้น TC-CAS-00x พิสูจน์ได้แค่ว่า **ค่า boolean ที่เราคำนวณ** (`!params.row.plant`) ถูกต้อง
> แต่**จับบั๊กไม่ได้**ว่า MUI Select จริงแสดงสถานะ disabled ใน DOM อย่างไร
>
> เพราะ MUI ใส่ `data-testid` ไว้บน `<div>` ชั้นนอก (ซึ่งไม่ใช่ form element)
> ตัว disabled จริงอยู่ที่ `[role="combobox"]` ข้างใน (เป็น `aria-disabled`)
> — ช่องว่างนี้ต้องให้ **e2e** เป็นคนปิด ดู Step 32 ของ `cost-center-master-flow.spec.ts`
> ที่ต้องเขียน `.getByRole('combobox')` ซ้อนใน testid แทนที่จะใช้ testid ตรงๆ

**บทเรียน**: ทุกการ mock คือการ**แลก** — ได้ความเร็วและความง่าย แต่เสียความสมจริง
สิ่งที่ดีคือ **เขียนคอมเมนต์บอกไว้ว่าเสียอะไรไป และใครเป็นคนรับผิดชอบส่วนที่เสีย**

---

## 6.3 helper ที่ต้องเข้าใจก่อน ⭐

```ts
const ADD_ROW_SUFFIX = '--1'; // TEMP_ADD_ID (-1) rendered into the testId template `-${id}`
```

testId ของ input ในตารางสร้างจากแม่แบบ `` `wpef1121-input-cost-center-${id}` ``
แถวใหม่ที่ยังไม่มี id จริงใช้ `-1` เป็น id ชั่วคราว → testId จึงกลายเป็น
`wpef1121-input-cost-center--1` (มีขีด 2 อัน: ขีดคั่น + ขีดลบ)

```ts
async function openAdd(store): Promise<void> {
    fireEvent.click(screen.getByTestId('wpef1121-btn-add'));
    await waitFor(() => {
        expect(store.getState()....datagrid.gridMode).toBe('ADD');
    });
    await waitFor(() => {
        expect(screen.getByTestId(`wpef1121-input-cost-center${ADD_ROW_SUFFIX}`)).toBeInTheDocument();
    });
}
```

**คอมเมนต์ในโค้ดอธิบายไว้ชัดมากว่าทำไมต้อง "กดปุ่มจริง" ไม่ใช่ตั้ง state ล่วงหน้า**:

> การเข้า ADD/EDIT ด้วยการ**คลิกปุ่มจริง** (แทนที่จะ preload `gridMode`/`editableId` ลง store)
> สำคัญมาก เพราะ `localRows` — ซึ่งเป็น `useState` ของ component เอง **ไม่ได้อยู่ใน Redux** —
> ถูกเติมค่าโดย `handleAdd`/`handleEdit` เท่านั้น
>
> ถ้า preload แค่ `gridMode` → `localRows` จะยังเป็น `[]` → แถวใหม่ (และ input ข้างใน)
> จะ**ไม่ถูก mount เลย** ทั้งที่เทสเช็คปุ่มแล้วดูเหมือนถูกต้องทุกอย่าง

**บทเรียนสำคัญมาก**: component ที่มี state อยู่ **2 ที่** (Redux + useState ในตัวเอง)
การตั้งแค่ Redux ไม่พอ — ต้องเดินผ่าน flow จริงเพื่อให้ state ทั้งสองฝั่งตรงกัน

```ts
beforeEach(() => {
    MockAPI.getDropdownMaintainDepartment.mockResolvedValue(new RestJsonResponse(null, null, departmentOptions));
    MockAPI.getDropdownMaintainShop.mockResolvedValue(new RestJsonResponse(null, null, shopOptions));
});
```

คอมเมนต์อธิบายว่า: ทุกเทสที่เปิด Add/Edit จะไป trigger การโหลด dropdown เหล่านี้เสมอ
ถ้าปล่อยเป็น auto-mock (คืน `undefined`) → reducer จะ throw ตอนอ่าน `action.payload.messageCode`
ทำให้ interaction ที่เทสกำลังจะทดสอบถูกขัดจังหวะ → ตั้งค่า default ไว้กลางๆ ให้ทุกเทส

---

## 6.4 กลุ่ม 1: `button visibility` — ปุ่มไหนเปิด/ปิดเมื่อไหร่

```ts
it('TC-BTN-001: Add enabled, Edit disabled in Initial Mode (no search run yet)', () => {
    buildAndRender({ screenMode: AppConstants.SCREEN_MODE.INIT });
    expect(screen.getByTestId('wpef1121-btn-add')).toBeEnabled();
    expect(screen.getByTestId('wpef1121-btn-edit')).toBeDisabled();
});
```

| TC | สถานะ | Add | Edit | Save/Cancel |
|---|---|---|---|---|
| TC-BTN-001 | INIT (ยังไม่ค้นหา) | ✅ เปิด | ❌ ปิด | — |
| TC-BTN-002 | VIEW (ค้นหาแล้ว) | ✅ เปิด | ✅ เปิด | — |
| TC-BTN-003 | ADD | ❌ ปิด | ❌ ปิด | มี |
| TC-BTN-004 | EDIT | ❌ ปิด | ❌ ปิด | มี |
| TC-BTN-005 | VIEW | — | — | **ไม่มี** |

**เหตุผลเบื้องหลัง**:
- TC-BTN-001: ยังไม่ได้ค้นหา = ยังไม่มีแถวให้แก้ → Edit ต้องปิด (แต่ Add ได้ เพราะเพิ่มใหม่ไม่ต้องมีข้อมูลเดิม)
- TC-BTN-003/004: กำลังแก้อยู่ ต้องจบให้เรียบร้อยก่อน → ปิด Add/Edit กันเปิดซ้อน
- TC-BTN-005: ใช้ `queryByTestId` + `not.toBeInTheDocument()` เพราะ Save/Cancel
  **ไม่ถูก render เลย** ในโหมด VIEW (ต่างจาก "render แต่ disabled")

---

## 6.5 กลุ่ม 2: `Add row`

```ts
it('TC-ADD-001: clicking Add sets gridMode to ADD with editableId -1', async () => {
    const store = buildAndRender();
    fireEvent.click(screen.getByTestId('wpef1121-btn-add'));
    await waitFor(() => {
        expect(...datagrid.gridMode).toBe('ADD');
        expect(...datagrid.editableId).toBe(-1);      // id ชั่วคราวของแถวใหม่
    });
});

it('TC-ADD-002: clicking Add appends a new row after the existing rows, numbered existingCount + 1', async () => {
    buildAndRender();
    fireEvent.click(screen.getByTestId('wpef1121-btn-add'));

    await waitFor(() => {
        const allRows = screen.getAllByRole('row');
        const dataRows = allRows.slice(1);            // ตัดแถว header ออก
        expect(dataRows).toHaveLength(3);             // เดิม 2 + ใหม่ 1
        expect(dataRows[2].textContent).toContain('3');   // คอลัมน์ "No." = 2 + 1
    });
});
```

**TC-ADD-002 น่าสนใจ**: แทนที่จะเช็ค state เช็คจาก **DOM จริง** ว่ามีกี่แถว
และแถวใหม่ต่อ**ท้าย** (index 2) ไม่ใช่แทรกข้างบน

`getAllByRole('row')` ดึงทุก `<tr>` รวม header → ต้อง `.slice(1)` ตัดทิ้ง

> **ทำไมใช้ `getAllByRole` แทน testId**: `role` เป็นมาตรฐาน accessibility
> ที่ MUI DataGrid ใส่ให้อัตโนมัติ — การเทสผ่าน role ทำให้เทสใกล้เคียงกับ
> "สิ่งที่ผู้ใช้ (และ screen reader) เห็น" มากกว่า

---

## 6.6 กลุ่ม 3: `Edit row` — กฎการเลือกแถว

```ts
it('TC-EDT-001: clicking Edit with no row selected shows SELECT_RECORD', async () => {
    buildAndRender();
    fireEvent.click(screen.getByTestId('wpef1121-btn-edit'));
    await waitFor(() => {
        expect(BannerNotificationUtils.showCommonMessage).toHaveBeenCalledWith('SELECT_RECORD');
    });
});

it('TC-EDT-002: clicking Edit with two rows selected shows SELECT_ONLY_ONE_ROW (ADR-0003)', async () => {
    const store = buildAndRender({ datagrid: { ...makeInitialState().datagrid, selectedRowIds: [1, 2] } });
    await act(async () => { store.dispatch(rxSetSelectedRowIds([1, 2])); });

    fireEvent.click(screen.getByTestId('wpef1121-btn-edit'));

    await waitFor(() => {
        expect(BannerNotificationUtils.showCommonMessage).toHaveBeenCalledWith('SELECT_ONLY_ONE_ROW');
    });
});

it('TC-EDT-003: clicking Edit with one row selected sets gridMode to EDIT', async () => {
    // ... selectedRowIds: [1]
    await waitFor(() => {
        expect(...datagrid.gridMode).toBe('EDIT');
        expect(...datagrid.editableId).toBe(1);
    });
});
```

**3 เทสนี้ครอบคลุมครบทุกทาง**: เลือก 0 แถว / 2 แถว / 1 แถว

> `(ADR-0003)` ในชื่อเทสคือการอ้าง **Architecture Decision Record** ฉบับที่ 3
> ของโปรเจกต์ — เป็นการบอกว่า "กฎนี้ไม่ได้คิดเอง มีเอกสารตัดสินใจรองรับ"
> ใครจะแก้ต้องไปอ่าน ADR ก่อน

> `act(async () => { store.dispatch(...) })` — ห่อ dispatch ที่ทำให้ React re-render
> เพื่อให้ React ประมวลผลเสร็จก่อนไปเช็คบรรทัดถัดไป

---

### TC-EDT-004 — เข้า Edit ต้องโหลด dropdown ตามค่าเดิมของแถว ⭐

```ts
it('TC-EDT-004: entering Edit pre-loads Department/Shop dropdowns scoped to the selected row\'s existing Plant/Department', async () => {
    const store = buildAndRender({ datagrid: { ...makeInitialState().datagrid, selectedRowIds: [1] } });
    await act(async () => { store.dispatch(rxSetSelectedRowIds([1])); });

    fireEvent.click(screen.getByTestId('wpef1121-btn-edit'));

    await waitFor(() => {
        expect(MockAPI.getDropdownMaintainDepartment).toHaveBeenCalledWith('SR');       // Plant ของแถวนั้น
        expect(MockAPI.getDropdownMaintainShop).toHaveBeenCalledWith('SR', 'P1');       // + Department ของแถวนั้น
    });
});
```

**เช็คอะไร**: `mockRow` มี `plant: 'SR'`, `department: 'P1'` อยู่แล้ว
พอกด Edit ต้องโหลดตัวเลือกที่**สอดคล้องกับค่าเดิม**ทันที

**ถ้าไม่ทำจะเป็นยังไง**: user กด Edit → dropdown Department ว่างเปล่า
ทั้งที่ช่องแสดงค่า `P1` อยู่ → พอคลิกเปิด dropdown ค่าที่เลือกไว้จะหายทันที
เป็นบั๊ก UX ที่เจอบ่อยมากในระบบที่มี dropdown แบบลูกโซ่

---

## 6.7 กลุ่ม 4: `read-only columns` — ช่องไหนแก้ได้/ไม่ได้ตอน Edit

```ts
it('TC-RO-001: Effective From/Cost Center/Shift are not editable, Line Code/Description/Plant/Department/Shop still are', async () => {
    const store = buildAndRender();
    await openEdit(store, 1);

    const row = screen.getByTestId('wpef1121-input-line-code-1').closest('[data-id]') as HTMLElement;
    const cellClass = (field: string) => row.querySelector(`[data-field="${field}"]`)?.className ?? '';

    expect(cellClass('effectiveFrom')).not.toContain('MuiDataGrid-cell--editable');
    expect(cellClass('costCenter')).not.toContain('MuiDataGrid-cell--editable');
    expect(cellClass('shift')).not.toContain('MuiDataGrid-cell--editable');
    expect(cellClass('lineCode')).toContain('MuiDataGrid-cell--editable');
    expect(cellClass('description')).toContain('MuiDataGrid-cell--editable');
    expect(cellClass('plant')).toContain('MuiDataGrid-cell--editable');
    expect(cellClass('department')).toContain('MuiDataGrid-cell--editable');
    expect(cellClass('shop')).toContain('MuiDataGrid-cell--editable');
});
```

**เช็คอะไร**: 3 ช่องที่เป็น **key ของข้อมูล** (Effective From + Cost Center + Shift)
ห้ามแก้ตอน Edit เพราะถ้าแก้ได้ = กลายเป็นคนละ record ไปเลย
(ถ้าอยากเปลี่ยน ต้องลบแล้วเพิ่มใหม่)

**ตรงกับกติกาใน `validation.schema.spec.ts`**: TC-VAL-004/010 บอกว่า
`effectiveFrom`/`costCenter` ไม่ required ตอน UPDATE — เพราะ**แก้ไม่ได้อยู่แล้ว** นั่นเอง
เทส 2 ไฟล์นี้จึงเป็นคู่หูกัน

**เทคนิคที่ใช้**:
- `.closest('[data-id]')` — จาก element ลูก ไต่ขึ้นไปหา element แม่ที่มี attribute `data-id` (= แถว)
- `[data-field="..."]` — MUI DataGrid ใส่ attribute นี้ให้ทุกช่อง ใช้เจาะจงคอลัมน์ได้
- เช็คจาก **CSS class** `MuiDataGrid-cell--editable` ที่ MUI ใส่ให้เอง

> วิธีนี้ผูกกับ internal ของ MUI (ถ้า MUI เปลี่ยนชื่อ class เทสจะพัง)
> แต่เป็นทางเลือกที่ดีที่สุดที่มี เพราะไม่มี API สาธารณะให้ถามว่า "ช่องนี้แก้ได้ไหม"

---

## 6.8 กลุ่ม 5: `Plant cascade` — dropdown ลูกโซ่ ⭐⭐

โครงสร้าง: **Plant → Department → Shop** (เลือกตัวซ้ายก่อน ตัวขวาถึงใช้ได้)

### TC-CAS-001 / TC-CAS-002 — ยังไม่เลือกตัวแม่ ตัวลูกต้อง disabled

```ts
it('TC-CAS-001: Department is disabled until a row has a Plant', async () => {
    const store = buildAndRender();
    await openAdd(store);
    expect(screen.getByTestId(`wpef1121-select-department${ADD_ROW_SUFFIX}`)).toBeDisabled();
});

it('TC-CAS-002: Shop is disabled until a row has a Department', async () => {
    const store = buildAndRender();
    await openAdd(store);
    expect(screen.getByTestId(`wpef1121-select-shop${ADD_ROW_SUFFIX}`)).toBeDisabled();
});
```

---

### TC-CAS-003 — เลือก Plant → โหลด Department ของ Plant นั้น

```ts
it('TC-CAS-003: choosing a Plant loads the Department dropdown scoped to it', async () => {
    const store = buildAndRender();
    await openAdd(store);

    fireEvent.change(screen.getByTestId(`wpef1121-select-plant${ADD_ROW_SUFFIX}`), { target: { value: 'SR' } });

    await waitFor(() => {
        expect(MockAPI.getDropdownMaintainDepartment).toHaveBeenCalledWith('SR');
    });
});
```

---

### TC-CAS-004 — เปลี่ยน Plant ต้องล้างตัวที่เลือกไว้ข้างล่าง ⭐

```ts
it('TC-CAS-004: re-choosing a different Plant resets Department/Shop back to SELECT', async () => {
    const store = buildAndRender();
    await openAdd(store);

    // 1. เลือกครบทั้งลูกโซ่: Plant=SR → Department=P1
    fireEvent.change(getByTestId(`wpef1121-select-plant${ADD_ROW_SUFFIX}`), { target: { value: 'SR' } });
    await waitFor(() => expect(MockAPI.getDropdownMaintainDepartment).toHaveBeenCalledWith('SR'));
    fireEvent.change(getByTestId(`wpef1121-select-department${ADD_ROW_SUFFIX}`), { target: { value: 'P1' } });
    await waitFor(() => expect(MockAPI.getDropdownMaintainShop).toHaveBeenCalledWith('SR', 'P1'));

    // 2. เปลี่ยนใจ เปลี่ยน Plant เป็น BP
    fireEvent.change(getByTestId(`wpef1121-select-plant${ADD_ROW_SUFFIX}`), { target: { value: 'BP' } });

    // 3. ค่าที่เลือกไว้ข้างล่างต้องถูกล้าง
    await waitFor(() => {
        expect(getByTestId(`wpef1121-select-department${ADD_ROW_SUFFIX}`)).toHaveValue(AppConstants.SELECT_ITEM.SELECT);
        expect(getByTestId(`wpef1121-select-shop${ADD_ROW_SUFFIX}`)).toHaveValue(AppConstants.SELECT_ITEM.SELECT);
    });
});
```

**เช็คอะไร**: นี่คือบั๊กที่เกิดบ่อยที่สุดของ cascade dropdown

ถ้าไม่ล้าง → user เลือก `Plant=SR, Department=P1` แล้วเปลี่ยนเป็น `Plant=BP`
ค่า `P1` จะค้างอยู่ทั้งที่ไม่มีอยู่ใน BP → กด Save → backend reject
หรือแย่กว่านั้นคือ**บันทึกข้อมูลที่ไม่ถูกต้อง**ลงไป

สังเกตว่าต้องล้าง **2 ระดับ** (ทั้ง Department และ Shop) เพราะ Shop ผูกกับ Department อีกที

---

### TC-CAS-005 / TC-CAS-006 — เลือกกลับเป็น `SELECT` ต้อง "ล้าง" ไม่ใช่ "โหลดใหม่"

```ts
it('TC-CAS-005: clearing Plant back to SELECT clears the Department dropdown instead of reloading it', async () => {
    const store = buildAndRender();
    await openAdd(store);

    fireEvent.change(getByTestId(`wpef1121-select-plant${ADD_ROW_SUFFIX}`), { target: { value: 'SR' } });
    await waitFor(() => expect(MockAPI.getDropdownMaintainDepartment).toHaveBeenCalledWith('SR'));

    // เลือกกลับเป็น placeholder
    fireEvent.change(getByTestId(`wpef1121-select-plant${ADD_ROW_SUFFIX}`), { target: { value: AppConstants.SELECT_ITEM.SELECT } });

    await waitFor(() => {
        expect(store.getState()....dropdown.maintainDepartment).toEqual([
            { name: SELECT, value: SELECT },
        ]);
    });
});
```

**เช็คอะไร**: เป็นเคสที่ลืมง่ายมาก — ถ้าโค้ดเขียนแค่
```ts
const handlePlantChange = (value) => {
    dispatch(rxLoadDropdownMaintainDepartment(value));   // ❌ ยิงทุกครั้ง
};
```
พอ user เลือกกลับเป็น `SELECT` ก็จะยิง `getDropdownMaintainDepartment('SELECT')`
ไปที่ backend → ได้ error หรือผลลัพธ์ประหลาด

โค้ดที่ถูกต้องต้องแยกทาง:
```ts
if (value === SELECT) {
    dispatch(rxClearMaintainDepartment());              // ✅ ล้างเฉยๆ ไม่ยิง API
} else {
    dispatch(rxLoadDropdownMaintainDepartment(value));
}
```

**สังเกตว่าเทสนี้เช็คที่ Redux state** (`store.getState()`) ไม่ใช่ที่หน้าจอ —
เพราะสิ่งที่อยากพิสูจน์คือ "ตัวเลือกใน store ถูกล้าง" ซึ่งดูจาก DOM ยากกว่า

> **นี่คือที่มาของ TC-MD-001/TC-MS-001 ใน[04-rtk-slice](vitest-lerning-ep3-04-rtk-slice.md)** — ตอนนั้นเราเทส reducer `rxClearMaintainDepartment`
> ว่าล้างถูกไหม ตอนนี้เราเทสว่า component **เรียกมันในจังหวะที่ถูก** — ครบทั้ง 2 ชั้น

---

## 6.9 กลุ่ม 6: `Cancel`

```ts
it('TC-CAN-001: confirming Cancel in ADD mode clears editableId and returns gridMode to VIEW', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    const store = buildAndRender({ datagrid: { ...makeInitialState().datagrid, gridMode: 'ADD', editableId: -1 } });

    fireEvent.click(screen.getByTestId('wpef1121-btn-cancel'));

    await waitFor(() => {
        const state = store.getState()....datagrid;
        expect(state.gridMode).toBe('VIEW');
        expect(state.editableId).toBeNull();
    });
});
```
TC-CAN-002 คือเคสเดียวกันแต่เป็นโหมด EDIT

---

### TC-CAN-003 — กด "ไม่" ใน dialog ต้องไม่เกิดอะไรขึ้น

```ts
it('TC-CAN-003: dismissing the Cancel confirm dialog keeps gridMode unchanged', async () => {
    (ConfirmDialogUtils.showDialogConfirmCancelChange as Mock).mockResolvedValueOnce('NO');
    const store = buildAndRender({ datagrid: { ..., gridMode: 'ADD', editableId: -1 } });

    fireEvent.click(screen.getByTestId('wpef1121-btn-cancel'));

    await waitFor(() => {
        expect(store.getState()....datagrid.gridMode).toBe('ADD');   // ยังอยู่ ADD เหมือนเดิม
    });
});
```

**เช็คอะไร**: dialog ถามว่า "ยกเลิกจริงไหม ข้อมูลจะหาย" → user กด **No**
→ ต้องอยู่ที่เดิม ไม่มีอะไรเปลี่ยน

**ทำไมสำคัญ**: ถ้าโค้ดเขียนผิดเป็นล้าง state ก่อนแล้วค่อยถาม (หรือไม่เช็คคำตอบ)
→ dialog กลายเป็นแค่ของประดับ user กด No แล้วงานก็หายอยู่ดี

---

### TC-CAN-004 — Cancel ต้องค้นหาใหม่จากหน้า 1 เสมอ ⭐⭐

```ts
// Regression for the flaky e2e "Edit -> Cancel -> No Data Found" failure: if the grid was left
// on a non-first page by an earlier, unrelated interaction, Cancel's re-search must not silently
// reuse that stale page — a single-row filter would then query a page past its own result set
// and come back empty even though the record is still there on page 0.
it('TC-CAN-004: confirming Cancel always re-searches from page 0, even if the grid was left on a later page', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    const store = buildAndRender({
        datagrid: { ..., gridMode: 'EDIT', editableId: 1, selectedRowIds: [1],
                    paginationModel: { page: 2, pageSize: DEFAULT_DATAGRID_PAGE_SIZE } },   // อยู่หน้า 3
    });

    fireEvent.click(screen.getByTestId('wpef1121-btn-cancel'));

    await waitFor(() => {
        expect(store.getState()....datagrid.paginationModel.page).toBe(0);
    });
    expect(MockAPI.search).toHaveBeenCalledWith(expect.objectContaining({ page: 0 }));
});
```

**เทสนี้มีที่มาจากบั๊กจริง** (คอมเมนต์บอกว่าเป็น regression test ของ e2e ที่แดงแบบสุ่ม):

```
1. user ค้นหา → ได้ผลหลายหน้า → เปิดไปดูหน้า 3
2. user แก้ criteria ให้แคบลง → เหลือผลลัพธ์แค่ 1 แถว (อยู่หน้า 1)
3. user กด Edit → กด Cancel
4. Cancel ค้นหาใหม่ แต่ยังใช้ page = 2 ค้างอยู่
5. → ค้นหาหน้า 3 ของผลลัพธ์ที่มีแค่หน้าเดียว → ได้ว่าง → "No Data Found" 😱
```

**สังเกตว่า assert 2 ชั้น**:
1. `paginationModel.page` ใน state = 0
2. payload ที่ยิงไป API มี `page: 0`

เพราะถ้าเช็คแค่ state อาจเกิดกรณีที่ state อัปเดตหลังยิง API ไปแล้ว (ยิงด้วย page เก่า)
→ ต้องเช็คทั้งคู่ถึงจะปิดช่องโหว่ได้จริง

> คำว่า **regression test** = เทสที่เขียนขึ้น**หลังเจอบั๊ก** เพื่อกันไม่ให้บั๊กเดิมกลับมา
> เทสแบบนี้มีค่าสูงมาก เพราะพิสูจน์แล้วว่า "เคยพังจริง"

---

### TC-CAN-005 — เส้นทางหลัก Edit → Cancel ผ่านปุ่มจริง

```ts
it('TC-CAN-005: opening Edit via the Edit button then clicking Cancel returns to View mode (mainline Edit -> Cancel path)', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    const store = buildAndRender();
    await openEdit(store, 1);                                  // ← ผ่าน flow จริง

    fireEvent.click(screen.getByTestId('wpef1121-btn-cancel'));

    await waitFor(() => {
        expect(state.gridMode).toBe('VIEW');
        expect(state.editableId).toBeNull();
    });
});
```

**ต่างจาก TC-CAN-002 ตรงไหน**: TC-CAN-002 **preload** `gridMode: 'EDIT'` ลง store
แต่ TC-CAN-005 **กดปุ่ม Edit จริง** — จึงมี `localRows` ที่เติมโดย `handleEdit` ด้วย
(ตามที่คอมเมนต์ของ `openEdit` เตือนไว้ในหัวข้อ 6.3)

TC-CAN-005 จึงสมจริงกว่า และจับบั๊กที่เกิดจาก state 2 ฝั่งไม่ตรงกันได้

---

## 6.10 กลุ่ม 7: `Save (Add)` — จุดที่ทุกอย่างมาบรรจบ

### TC-SAV-001 — ไม่กรอกอะไรเลยแล้วกด Save

```ts
it('TC-SAV-001: saving an Add row with every field left empty shows validation errors and never calls the API', async () => {
    const store = buildAndRender();
    await openAdd(store);

    fireEvent.click(screen.getByTestId('wpef1121-btn-save'));

    await waitFor(() => {
        expect(BannerNotificationUtils.show).toHaveBeenCalledWith(
            expect.arrayContaining([
                expect.objectContaining({ message: expect.stringContaining('label.COL_EFFECTIVE_FROM') }),
                expect.objectContaining({ message: expect.stringContaining('label.COL_COST_CENTER') }),
                expect.objectContaining({ message: expect.stringContaining('label.COL_LINE_CODE') }),
            ])
        );
    });
    expect(MockAPI.saveAdd).not.toHaveBeenCalled();
});
```

**เช็คอะไร**: validate ฝั่ง client ต้องทำงาน → ขึ้น banner หลายข้อความ → **ห้ามยิง API**

> `expect.arrayContaining([...])` = "array นี้ต้องมีสมาชิกเหล่านี้อยู่ (จะมีตัวอื่นด้วยก็ได้)"
> `expect.objectContaining({...})` = "object นี้ต้องมี field เหล่านี้ตรง (จะมี field อื่นด้วยก็ได้)"
> `expect.stringContaining('...')` = "string นี้ต้องมีข้อความนี้อยู่ข้างใน"
>
> ซ้อนกัน 3 ชั้นแบบนี้แปลว่า: *"ใน array ของ error ต้องมี object ที่มี field `message`
> ซึ่งข้างในมีคำว่า `label.COL_EFFECTIVE_FROM`"* — ยืดหยุ่นพอที่จะไม่พังเวลา
> ข้อความ error เปลี่ยนรูปแบบเล็กน้อย

**เชื่อมโยงกับ[03-validation](vitest-lerning-ep3-03-validation.md)**: กติกาที่ทำให้ error พวกนี้เกิด คือกติกาเดียวกับที่
`validation.schema.spec.ts` เทสไว้ (TC-VAL-003/008/011) — ไฟล์นั้นเทส "กติกาถูกไหม"
ไฟล์นี้เทส "component เอากติกาไปใช้จริงไหม"

---

### TC-SAV-002 — กรอกครบแล้ว Save สำเร็จ (เทสที่ยาวที่สุด)

```ts
it('TC-SAV-002: saving a fully-filled Add row calls API.saveAdd with the entered values and resets to page 0 on success', async () => {
    MockAPI.saveAdd.mockResolvedValue(new RestJsonResponse<number>(null, null, 999));
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    const store = buildAndRender();
    await openAdd(store);

    // กรอกทุกช่อง
    fireEvent.change(getNativeField(`wpef1121-date-effective-from${ADD_ROW_SUFFIX}`), { target: { value: '2030-01-01' } });
    fireEvent.change(getNativeField(`wpef1121-input-cost-center${ADD_ROW_SUFFIX}`), { target: { value: 'ZZE2E001' } });
    fireEvent.change(getNativeField(`wpef1121-input-line-code${ADD_ROW_SUFFIX}`), { target: { value: 'ZZLINE01' } });
    fireEvent.change(getNativeField(`wpef1121-input-description${ADD_ROW_SUFFIX}`), { target: { value: 'E2E ADD SUCCESS' } });
    fireEvent.change(getByTestId(`wpef1121-select-shift${ADD_ROW_SUFFIX}`), { target: { value: 'W' } });

    // dropdown ลูกโซ่: ต้องรอ API แต่ละขั้นก่อนไปขั้นถัดไป
    fireEvent.change(getByTestId(`wpef1121-select-plant${ADD_ROW_SUFFIX}`), { target: { value: 'SR' } });
    await waitFor(() => expect(MockAPI.getDropdownMaintainDepartment).toHaveBeenCalled());
    fireEvent.change(getByTestId(`wpef1121-select-department${ADD_ROW_SUFFIX}`), { target: { value: 'P1' } });
    await waitFor(() => expect(MockAPI.getDropdownMaintainShop).toHaveBeenCalled());
    fireEvent.change(getByTestId(`wpef1121-select-shop${ADD_ROW_SUFFIX}`), { target: { value: '(W)' } });

    fireEvent.click(screen.getByTestId('wpef1121-btn-save'));

    await waitFor(() => {
        expect(MockAPI.saveAdd).toHaveBeenCalledWith(
            expect.objectContaining({
                costCenter: 'ZZE2E001', lineCode: 'ZZLINE01', description: 'E2E ADD SUCCESS',
                shift: 'W', plant: 'SR', department: 'P1', shop: '(W)',
            })
        );
    });
    await waitFor(() => {
        expect(...triggerSearchResetPage).toBe(false);   // ถูกใช้แล้วและปิดกลับ
    });
    expect(BannerNotificationUtils.showSaveSuccess).toHaveBeenCalled();
});
```

**เช็คอะไร** — flow เต็มตั้งแต่ต้นจนจบ:
1. กรอกครบทุกช่อง (รวม dropdown ลูกโซ่ที่ต้องรอทีละขั้น)
2. กด Save → dialog ตอบ YES อัตโนมัติ (จาก mock)
3. `API.saveAdd` ถูกเรียกด้วยค่าที่กรอกไปเป๊ะ
4. สำเร็จ → ขึ้น banner สำเร็จ
5. `triggerSearchResetPage` กลับเป็น `false` = ถูก effect ค้นหา "บริโภค" ไปแล้ว
   (แปลว่าค้นหาใหม่จากหน้า 1 เรียบร้อย)

**จุดที่ต้องเข้าใจ**: `await waitFor(...)` ระหว่างเลือก dropdown **จำเป็น**
ถ้าเลือก Department ทันทีโดยไม่รอ ตัวเลือกยังไม่โหลดมา → `<select>` จะไม่มี `<option>` นั้น
→ `fireEvent.change` ไม่มีผล → ค่าเป็น SELECT → validate ไม่ผ่าน → เทสแดงแบบงงๆ

```ts
const getNativeField = (testId: string): HTMLInputElement => {
    const element = screen.getByTestId(testId);
    return (element.querySelector('input') ?? element) as HTMLInputElement;
};
```
helper นี้จัดการความต่างของ 2 กรณี: บาง component ใส่ testId ไว้ที่ `<div>` ครอบ
(ต้องเจาะเข้าไปหา `<input>` ข้างใน) บางตัวใส่ที่ `<input>` ตรงๆ (ใช้ได้เลย)

---

### TC-SAV-003 — backend ตอบ error

```ts
it('TC-SAV-003: a backend error response on Add is shown via showServerMessage, not the success banner', async () => {
    MockAPI.saveAdd.mockResolvedValue(new RestJsonResponse<number>('MPEF11201ERR', 'MPEF11201ERR: duplicate key', 0));
    // ... กรอกครบเหมือน TC-SAV-002 ...
    fireEvent.click(screen.getByTestId('wpef1121-btn-save'));

    await waitFor(() => {
        expect(BannerNotificationUtils.showServerMessage).toHaveBeenCalledWith('MPEF11201ERR: duplicate key', 'MPEF11201ERR');
    });
    expect(BannerNotificationUtils.showSaveSuccess).not.toHaveBeenCalled();
    // Still in ADD mode — an error response must not silently close the row.
    expect(store.getState()....datagrid.gridMode).toBe('ADD');
});
```

**เช็ค 3 อย่าง**:
1. แสดงข้อความ error จาก server
2. **ไม่**แสดง banner สำเร็จ (กันบั๊ก "ขึ้นทั้งสองอัน")
3. **ยังอยู่ในโหมด ADD** — ข้อมูลที่กรอกต้องไม่หาย user จะได้แก้แล้ว Save ใหม่ได้

ข้อ 3 สำคัญที่สุด — ถ้าปิดแถวไปเลยตอน error user จะต้องกรอกใหม่ทั้งหมด

---

### TC-SAV-004 — กด No ใน dialog ยืนยัน

```ts
it('TC-SAV-004: dismissing the Save confirm dialog never calls the API', async () => {
    (ConfirmDialogUtils.showDialogConfirmSave as Mock).mockResolvedValueOnce('NO');
    // ... กรอกครบ ...
    fireEvent.click(screen.getByTestId('wpef1121-btn-save'));

    await waitFor(() => expect(ConfirmDialogUtils.showDialogConfirmSave).toHaveBeenCalled());
    expect(MockAPI.saveAdd).not.toHaveBeenCalled();
});
```

**จุดที่ต้องระวัง**: `await waitFor(() => expect(...showDialogConfirmSave).toHaveBeenCalled())`
— ต้องรอให้ dialog **ถูกเรียกก่อน** แล้วค่อยเช็คว่า API ไม่ถูกเรียก

ถ้าเช็ค `expect(MockAPI.saveAdd).not.toHaveBeenCalled()` ทันทีเลย เทสจะ**ผ่านแบบหลอกๆ**
เพราะ ณ วินาทีนั้น API ยังไม่ถูกเรียกอยู่แล้วแม้ในโค้ดที่ผิด (ยังไม่ทันถึงจังหวะ)

> นี่คือกับดักคลาสสิกของการเทส "สิ่งที่ต้องไม่เกิดขึ้น" —
> ต้องหา "จุดหมุด" (เหตุการณ์ที่ต้องเกิดแน่ๆ) มารอก่อนเสมอ

---

### TC-SAV-005 / TC-SAV-008 — validate ระดับแถว

```ts
it('TC-SAV-005: Effective To earlier than Effective From on the row itself blocks Save client-side', async () => {
    // ... กรอก From = 2026-10-01, To = 2026-09-01 (ย้อนหลัง) ...
    fireEvent.click(screen.getByTestId('wpef1121-btn-save'));

    await waitFor(() => {
        expect(BannerNotificationUtils.show).toHaveBeenCalledWith(
            expect.arrayContaining([expect.objectContaining({ message: expect.stringContaining('label.COL_EFFECTIVE_TO') })])
        );
    });
    expect(MockAPI.saveAdd).not.toHaveBeenCalled();
});

it('TC-SAV-008: a Cost Center longer than 8 characters is blocked with an EXCEED_MAX_LENGTH message carrying the field name/length', async () => {
    // ... กรอก costCenter = 'TOOLONGVALUE' (12 ตัว) ...
    await waitFor(() => {
        expect(BannerNotificationUtils.show).toHaveBeenCalledWith(
            expect.arrayContaining([
                expect.objectContaining({ message: expect.stringContaining('"fieldLength":"8"') }),
            ])
        );
    });
    expect(MockAPI.saveAdd).not.toHaveBeenCalled();
    expect(store.getState()....datagrid.gridMode).toBe('ADD');
});
```

**TC-SAV-008 มีจุดพิเศษ**: assert หา `'"fieldLength":"8"'` ซึ่งเป็น **JSON string**

มาจากการ mock `useTranslation` ตอนต้นไฟล์:
```ts
useTranslation: () => ({ t: (key, params) => (params ? `${key}|${JSON.stringify(params)}` : key) }),
```
ฟังก์ชันแปลปลอมจะต่อ key กับ params ที่เป็น JSON — ทำให้เทสตรวจได้ว่า
**พารามิเตอร์ถูกส่งไปให้ i18n ครบ** ไม่ใช่แค่ key ถูก

ทำไมสำคัญ: ข้อความจริงคือ *"Cost Center must not exceed 8 characters"* —
เลข `8` ต้องถูกส่งเข้าไป ถ้าลืมส่ง user จะเห็น *"must not exceed {{fieldLength}} characters"*

**เชื่อมโยงกับ[03-validation](vitest-lerning-ep3-03-validation.md) อีกครั้ง**: TC-VAL-005 (date range) และ TC-VAL-009 (max length)
เทสกติกาเดียวกันที่ระดับ schema — คู่นี้เทสว่ามันถูกเรียกใช้จริงจากหน้าจอ

---

## 6.11 กลุ่ม 8: `Save (Edit)`

### TC-SAV-006 — ส่ง id ที่ถูกต้องและกลับหน้า 1 ⭐⭐

```ts
it('TC-SAV-006: saving an edited existing row calls API.saveEdit with id/originalVersionNo from the row, and re-searches from page 0 like a fresh Search click', async () => {
    MockAPI.saveEdit.mockResolvedValue(new RestJsonResponse<number>(null, null, 1));
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    // Start on a later page — proves Save actually resets it, not just that it happens to already be 0.
    const store = buildAndRender({ datagrid: { ..., paginationModel: { page: 2, pageSize: DEFAULT_DATAGRID_PAGE_SIZE } } });
    await openEdit(store, 1);

    fireEvent.change(getNativeField('wpef1121-input-line-code-1'), { target: { value: 'EDITOK01' } });

    fireEvent.click(screen.getByTestId('wpef1121-btn-save'));

    await waitFor(() => {
        expect(MockAPI.saveEdit).toHaveBeenCalledWith(
            expect.objectContaining({
                id: mockRow.costCenterId,                      // ← 101 ไม่ใช่ 1 !!
                originalVersionNo: mockRow.originalVersionNo,
                lineCode: 'EDITOK01',
            })
        );
    });
    await waitFor(() => {
        expect(...datagrid.paginationModel.page).toBe(0);
    });
    expect(MockAPI.search).toHaveBeenCalledWith(expect.objectContaining({ page: 0 }));
});
```

**นี่คือเทสที่สำคัญที่สุดของไฟล์ทั้งไฟล์** เช็ค 3 เรื่องที่ร้ายแรงถ้าพลาด:

**① `id: mockRow.costCenterId`** — ต้องส่ง **101** (ID จริงใน DB) ไม่ใช่ **1** (เลขลำดับในหน้า)
นี่คือปลายทางของ logic ที่ TC-SCH-001 ([04-rtk-slice](vitest-lerning-ep3-04-rtk-slice.md)) เทสไว้ — ถ้าส่งผิดจะไป**แก้ข้อมูลผิดแถว**

**② `originalVersionNo`** — เลขเวอร์ชันตอนที่โหลดข้อมูลมา ใช้ทำ **optimistic locking**:
backend จะเทียบว่า "เวอร์ชันที่ client ถืออยู่ตรงกับใน DB ไหม" ถ้าไม่ตรงแปลว่ามีคนอื่นแก้ไปแล้ว
→ ปฏิเสธการบันทึก (ดู TC-SAV-007) ถ้าลืมส่ง field นี้ = ระบบป้องกันการแก้ชนกัน**ไม่ทำงานเลย**

**③ `paginationModel.page = 0`** — คอมเมนต์อธิบายว่าจงใจเริ่มที่หน้า 3 (`page: 2`)
เพื่อพิสูจน์ว่า Save **รีเซ็ตหน้าจริงๆ** ไม่ใช่บังเอิญเป็น 0 อยู่แล้ว

> เทคนิคนี้เรียกว่า **"ตั้งค่าเริ่มต้นให้ต่างจากผลที่คาดหวัง"** — ถ้าเริ่มที่ 0 และคาดหวัง 0
> เทสจะผ่านแม้โค้ดไม่ได้ทำอะไรเลย (false positive)

---

### TC-SAV-007 — มีคนอื่นแก้ไปแล้ว (concurrency)

```ts
it('TC-SAV-007: a CONCURRENCY_ERROR response on Edit is shown via showServerMessage', async () => {
    MockAPI.saveEdit.mockResolvedValue(new RestJsonResponse<number>('MAPI10001ERR', 'MAPI10001ERR: modified by another user', 0));
    const store = buildAndRender();
    await openEdit(store, 1);

    fireEvent.click(screen.getByTestId('wpef1121-btn-save'));

    await waitFor(() => {
        expect(BannerNotificationUtils.showServerMessage).toHaveBeenCalledWith('MAPI10001ERR: modified by another user', 'MAPI10001ERR');
    });
});
```

**สถานการณ์**: A กับ B เปิดแถวเดียวกัน → A กด Save ก่อน → B กด Save
→ `originalVersionNo` ของ B ล้าสมัยแล้ว → backend ปฏิเสธด้วย `MAPI10001ERR`

**เช็คอะไร**: frontend ต้องแสดงข้อความนี้ให้ B เห็น เพื่อให้ B รู้ว่าต้องโหลดใหม่
ไม่ใช่เงียบหายหรือขึ้นว่าบันทึกสำเร็จ

---

## 6.12 กลุ่ม 9: `Pagination`

```ts
it('TC-PAG-001: changing page dispatches a fresh search for the new page and clears row selection', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 25 }));
    const store = buildAndRender({ datagrid: { ..., total: 25, selectedRowIds: [1] } });

    fireEvent.click(screen.getByRole('button', { name: 'Go to page 2' }));

    await waitFor(() => {
        expect(MockAPI.search).toHaveBeenCalledWith(expect.objectContaining({ page: 1, pageSize: DEFAULT_DATAGRID_PAGE_SIZE }));
    });
    await waitFor(() => {
        expect(...datagrid.selectedRowIds).toEqual([]);      // ← การเลือกต้องถูกล้าง
    });
});
```

**เช็ค 2 อย่าง**:
1. ยิงค้นหาใหม่ด้วย `page: 1` (หน้า 2 = index 1)
2. **ล้างการเลือกแถว** — สำคัญมาก! เพราะ `id` เป็นเลขลำดับ**ในหน้านั้น** (ดู TC-SCH-005)
   ถ้าไม่ล้าง: เลือกแถว id=1 ในหน้า 1 → ไปหน้า 2 → แถวแรกของหน้า 2 ก็ id=1 เหมือนกัน
   → กลายเป็นเลือกแถวผิดโดยไม่รู้ตัว → กด Edit แล้วแก้ผิดแถว

> `getByRole('button', { name: 'Go to page 2' })` — หาปุ่มจาก **ชื่อที่ screen reader อ่าน**
> (aria-label ที่ MUI ใส่ให้) แทนที่จะใช้ testId เพราะปุ่มแบ่งหน้าเป็นของ MUI เราคุม testId ไม่ได้

```ts
it('TC-PAG-002: a server error on page change is shown via showServerMessage with the real message text', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse('MPEF11299ERR', 'MPEF11299ERR: search failed', { rows: [], total: 0 }));
    buildAndRender({ datagrid: { ..., total: 25 } });

    fireEvent.click(screen.getByRole('button', { name: 'Go to page 2' }));

    await waitFor(() => {
        expect(BannerNotificationUtils.showServerMessage).toHaveBeenCalledWith('MPEF11299ERR: search failed', 'MPEF11299ERR');
    });
});
```
**เช็คอะไร**: error ระหว่างเปลี่ยนหน้าก็ต้องแจ้ง user ไม่ใช่เงียบแล้วเหลือตารางว่าง

---

## 6.13 กลุ่ม 10: `search payload` — ค่าจาก criteria ต้องส่งครบ

```ts
it('TC-SRCH-001: searching with Plant/Shop/Shift/Department/CostCenter all populated passes them through as-is', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse(null, null, { rows: [], total: 0 }));
    buildAndRender({
        criteria: { effectiveFrom: null, effectiveTo: null, plant: ['SR'], shop: ['(W)'], shift: ['W'], department: ['P1'], costCenter: 'FBA1' },
        triggerSearch: true,      // ← ตั้งธงไว้ล่วงหน้า = สั่งให้ค้นหาทันทีที่ mount
    });

    await waitFor(() => {
        expect(MockAPI.search).toHaveBeenCalledWith(
            expect.objectContaining({ plant: ['SR'], shop: ['(W)'], shift: ['W'], department: ['P1'], costCenter: 'FBA1' })
        );
    });
});
```

**เทคนิคที่ใช้**: ตั้ง `triggerSearch: true` ไว้ใน preloadedState
→ พอ component mount ก็เห็นธงแล้วค้นหาทันที **โดยไม่ต้องกดปุ่มอะไรเลย**

ใช้ธงนี้ในการทดสอบทำให้ข้ามการจำลอง "กดปุ่ม Search ในฟอร์ม criteria" ไปได้เลย
(ซึ่งเป็นหน้าที่ของ `search.criteria.spec.tsx` ใน EP.2 อยู่แล้ว) — **ไม่เทสซ้ำ**

```ts
it('TC-SRCH-002: a server error from the initial search effect is shown via showServerMessage, falling back to an empty description when none is provided', async () => {
    MockAPI.search.mockResolvedValue(new RestJsonResponse('MPEF11205ERR', null, { rows: [], total: 0 } as any));
    buildAndRender({ triggerSearch: true });

    await waitFor(() => {
        expect(BannerNotificationUtils.showServerMessage).toHaveBeenCalledWith('', 'MPEF11205ERR');
    });
});
```
**เช็คอะไร**: error ที่ไม่มีข้อความอธิบาย (`null`) ต้อง fallback เป็น `''`
ไม่ใช่แสดงคำว่า `"null"` บนหน้าจอ — เคสเดียวกับ TC-SUB-007 ใน EP.2

---

## 6.14 สรุปส่วนที่ 6

| เทคนิค | ใช้ยังไง |
|---|---|
| mock MUI Select/DatePicker เป็น native | หลบ portal/widget ที่คุมยากใน jsdom |
| helper `openAdd`/`openEdit` | เดิน flow จริงเพื่อให้ state ทั้ง Redux + useState ตรงกัน |
| `mockResolvedValueOnce` | override พฤติกรรม mock เฉพาะเทสเดียว |
| `expect.arrayContaining` / `objectContaining` / `stringContaining` | assert แบบยืดหยุ่น ไม่ผูกกับรูปแบบข้อความเป๊ะ |
| `getByRole('button', { name })` | หา element ของ library ที่เราคุม testId ไม่ได้ |
| ตั้งค่าเริ่มต้นให้ต่างจากผลคาดหวัง | กัน false positive (เช่นเริ่มที่ page 2 เพื่อพิสูจน์ว่ารีเซ็ตจริง) |
| รอ "จุดหมุด" ก่อนเช็คสิ่งที่ต้องไม่เกิด | กันเทสผ่านแบบหลอกๆ |
| ตั้งธง `triggerSearch: true` | ข้ามขั้นตอนที่ไฟล์อื่นเทสไว้แล้ว |

---

