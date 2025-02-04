resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.rg_location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space = [ var.address_space ]
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  depends_on = [ azurerm_resource_group.rg ]
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  address_prefixes     = [var.address_prefixes]
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  depends_on = [ azurerm_virtual_network.vnet ]
}

resource "azurerm_public_ip" "appgw_pip" {
  name                = "AppGW_PubIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.rg ]
}

# Create an App Service Plan
resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type = "Windows"
  sku_name = "S1"
  depends_on = [ azurerm_resource_group.rg ]
}

# Create the Web App1
resource "azurerm_windows_web_app" "web_app1" {
  name                = var.web_app1_name
  location            = azurerm_service_plan.plan.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.plan.id
  site_config {
    always_on = true
  }
  depends_on = [ azurerm_resource_group.rg , azurerm_service_plan.plan ]
}

# Create the Web App2
resource "azurerm_windows_web_app" "web_app2" {
  name                = var.web_app2_name
  location            = azurerm_service_plan.plan.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.plan.id
  site_config {
    always_on = true
  }
  depends_on = [ azurerm_resource_group.rg , azurerm_service_plan.plan ]
}

# Create the Application Gateway 
resource "azurerm_application_gateway" "appgw" {
  name                = var.appGW_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  backend_address_pool {
    name         = "backend-pool-1"
    fqdns = ["${azurerm_windows_web_app.web_app1.name}.azurewebsites.net"]
  }

  backend_address_pool {
    name         = "backend-pool-2"
    fqdns = ["${azurerm_windows_web_app.web_app2.name}.azurewebsites.net"]
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule-1"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool-1"
    backend_http_settings_name = "http-settings"
  }

  request_routing_rule {
    name                       = "routing-rule-2"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool-2"
    backend_http_settings_name = "http-settings"
  }

  depends_on = [ azurerm_virtual_network.vnet , azurerm_subnet.subnet , azurerm_public_ip.appgw_pip ,
                azurerm_windows_web_app.web_app1 , azurerm_windows_web_app.web_app2 ]
}

