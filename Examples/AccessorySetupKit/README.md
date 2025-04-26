# AsyncCoreBluetooth AccessorySetupKit Example

This example shows how to create a Central on an iOS SwiftUI app using AsyncCoreBluetooth, using [`AccessorySetupKit`](https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories) for device descovery.

It is designed to connect to the ESP32S3 BLE GATT Server example from espressif.

## ESP32S3 BLE GATT Server

You don't need to set this up to view or run the example. But if you already have an ESP32S3 lying around with the esp idf already installed, then you might as well just flash the example:

https://docs.espressif.com/projects/esp-idf/en/v5.4/esp32s3/api-guides/ble/get-started/ble-introduction.html

https://github.com/espressif/esp-idf/blob/v5.4/examples/bluetooth/ble_get_started/nimble/NimBLE_GATT_Server/README.md


For this example, i had to modify the ESP code slightly to advertise the services and remove some of the other advertising data. Update the gap.c file:

```c
static void start_advertising(void) {
    /* Local variables */
    int rc = 0;
    const char *name;
    struct ble_hs_adv_fields adv_fields = {0};
    struct ble_hs_adv_fields rsp_fields = {0};
    struct ble_gap_adv_params adv_params = {0};

    /* Set advertising fields - keep minimal for size constraints */
    /* Set advertising flags */
    adv_fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;

    /* Add service UUIDs to advertising data */
    static ble_uuid16_t uuids[] = {
        BLE_UUID16_INIT(0x180D),  /* Heart Rate Service */
        BLE_UUID16_INIT(0x1815)   /* Automation IO Service */
    };
    adv_fields.uuids16 = uuids;
    adv_fields.num_uuids16 = 2;
    adv_fields.uuids16_is_complete = 1;

    /* Set device name - shortened version for adv packet */
    name = ble_svc_gap_device_name();
    adv_fields.name = (uint8_t *)name;
    adv_fields.name_len = strlen(name);
    adv_fields.name_is_complete = 0;  /* Indicate name is shortened */

    /* Set advertisement fields */
    rc = ble_gap_adv_set_fields(&adv_fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "failed to set advertising data, error code: %d", rc);
        return;
    }

    /* Set scan response fields - put other data here */
    /* Complete device name */
    rsp_fields.name = (uint8_t *)name;
    rsp_fields.name_len = strlen(name);
    rsp_fields.name_is_complete = 1;

    /* Set device tx power */
    rsp_fields.tx_pwr_lvl = BLE_HS_ADV_TX_PWR_LVL_AUTO;
    rsp_fields.tx_pwr_lvl_is_present = 1;

    /* Set device appearance */
    rsp_fields.appearance = BLE_GAP_APPEARANCE_GENERIC_TAG;
    rsp_fields.appearance_is_present = 1;

    /* Set device LE role */
    rsp_fields.le_role = BLE_GAP_LE_ROLE_PERIPHERAL;
    rsp_fields.le_role_is_present = 1;

    /* Set scan response fields */
    rc = ble_gap_adv_rsp_set_fields(&rsp_fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "failed to set scan response data, error code: %d", rc);
        return;
    }

    /* Set non-connetable and general discoverable mode to be a beacon */
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    /* Set advertising interval */
    adv_params.itvl_min = BLE_GAP_ADV_ITVL_MS(500);
    adv_params.itvl_max = BLE_GAP_ADV_ITVL_MS(510);

    /* Start advertising */
    rc = ble_gap_adv_start(own_addr_type, NULL, BLE_HS_FOREVER, &adv_params,
                          gap_event_handler, NULL);
    if (rc != 0) {
        ESP_LOGE(TAG, "failed to start advertising, error code: %d", rc);
        return;
    }
    ESP_LOGI(TAG, "advertising started!");
}
```
