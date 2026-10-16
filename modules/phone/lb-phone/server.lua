---@diagnostic disable: duplicate-set-field
local resourceName = "lb-phone"
if GetResourceState(resourceName) ~= 'started' then return end
local PhoneRequests = lib.require('@concept_bridge.lib.security.server.phone')
Phone = Phone or {}

---This will get the name of the Phone system being being used.
---@return string
Phone.GetPhoneName = function()
    return resourceName
end

Phone.GetResourceName = function()
    return resourceName
end

---This will get the phone number of the passed source.
---@param src number
---@return number|boolean
Phone.GetPlayerPhone = function(src)
    return exports["lb-phone"]:GetEquippedPhoneNumber(src) or false
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
local function sendEmail(src, email, title, message, request)
    local numberNumber = exports["lb-phone"]:GetEquippedPhoneNumber(src)
    if not numberNumber then return false, print(" ^6 Could not Find Phone number ^0") end
    local playerEmail = exports["lb-phone"]:GetEmailAddress(numberNumber)
    if not playerEmail then return false, print(" ^6 Could not Find email ^0")  end
    if request and not PhoneRequests.Current(request) then return false end
    local success, id = exports["lb-phone"]:SendMail({
        to = playerEmail,
        sender = email,
        subject = title,
        message = message,
    })
    return success or false
end

Phone.SendEmail = function(src, email, title, message)
    return sendEmail(src, email, title, message)
end

RegisterNetEvent('concept_bridge:Server:genericEmail', function(data)
    local src = tonumber(source)
    if not src or src <= 0 or type(data) ~= 'table' then return false end
    return PhoneRequests.Send(src, resourceName, sendEmail, data.email, data.title, data.message)
end)

return Phone