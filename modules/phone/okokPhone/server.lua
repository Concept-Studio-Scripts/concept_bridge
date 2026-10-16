---@diagnostic disable: duplicate-set-field
---@class NewEmail
---@field sender string
---@field recipients string[]
---@field subject string
---@field actions? EmailAction[]
---@field body string

---@class EmailAction
---@field id string
---@field label string
---@field event string?
---@field exports string?
---@field server boolean
---@field data any

local resourceName = "okokPhone"
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
    return exports.okokPhone:getPhoneNumberFromSource(src) or false
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
local function sendEmail(src, email, title, message, request)
    local senderAddress = exports.okokPhone:getEmailAddressFromSource(src) --[[ @as string? ]]
    if not senderAddress then return false end

    ---@type NewEmail
    local data = {
        sender = senderAddress,
        recipients = { email },
        subject = title,
        body = message,
    }

    if request and not PhoneRequests.Current(request) then return false end
    local success = exports.okokPhone:sendEmail(data) --[[ @as boolean ]]
    return success
end

Phone.SendEmail = function(src, email, title, message)
    return sendEmail(src, email, title, message)
end

lib.callback.register('concept_bridge:Callback:okokPhone:sendEmail', function(src, email, title, message, ...)
    if select('#', ...) ~= 0 then return false, 'invalid_payload' end
    return PhoneRequests.Send(src, resourceName, sendEmail, email, title, message, true)
end)

return Phone