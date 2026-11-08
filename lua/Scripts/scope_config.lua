-- Data-only scope file shared with the standalone Windows configurator.
-- Never load or execute configuration as Lua code.
local M = {}
M.filename = 'furigana-scope.ini'
local flags = {'full_text', 'weapons', 'characters', 'books'}
function M.defaults() return {full_text=true, weapons=false, characters=false, books=false} end
function M.parse(data)
    assert(type(data)=='string' and #data<=4096, 'Scope file exceeds 4096 bytes')
    data=data:gsub('^\239\187\191','')
    local values={}
    for raw in (data..'\n'):gmatch('(.-)\n') do
        local line=raw:gsub('\r$',''):match('^%s*(.-)%s*$')
        if line~='' and line:sub(1,1)~='#' then
            local key,value=line:match('^([a-z_]+)%s*=%s*([01])$')
            assert(key and (key=='version' or key=='full_text' or key=='weapons' or key=='characters' or key=='books'), 'Unknown scope setting')
            assert(values[key]==nil, 'Duplicate scope setting')
            values[key]=value
        end
    end
    assert(values.version=='1', 'Unsupported scope version')
    local result={}
    for _,key in ipairs(flags)do assert(values[key]~=nil,'Missing scope setting');result[key]=values[key]=='1' end
    assert(not result.full_text or not(result.weapons or result.characters or result.books),'Full text and categories are mutually exclusive')
    return result
end
function M.serialize(scope)
    local lines={'version=1'}
    for _,key in ipairs(flags)do assert(type(scope[key])=='boolean');lines[#lines+1]=key..'='..(scope[key]and'1'or'0')end
    local data=table.concat(lines,'\n')..'\n';M.parse(data);return data
end
function M.read(root,log)
    local file=io.open(root..M.filename,'rb')
    if not file then return M.defaults()end
    local data=file:read(4097);file:close()
    local ok,result=pcall(M.parse,data)
    if ok then return result end
    if log then log('scope_config_error '..tostring(result)..'; using full-text defaults')end
    return M.defaults()
end
function M.enabled(scope,key) return scope==nil or scope.full_text==true or scope[key]==true end
function M.any(scope) return M.enabled(scope,'weapons')or M.enabled(scope,'characters')or M.enabled(scope,'books')end
function M.watcher(scope,id)
    if not scope or scope.full_text then return true end
    if id=='subtitle'then return scope.characters end
    if id=='item'or id=='general_rich'then return M.any(scope)end
    if id=='detail_rows'then return scope.books or scope.characters end
    if id=='book_dense'or id=='book_subhead'or id=='book_tab'then return scope.books end
    return false
end
local function anyKey(entry,predicate)
    if entry.key and predicate(entry.key)then return true end
    for key,value in pairs(entry.keys or{})do
        local alias=type(key)=='number'and value or(value==true and key)
        if type(alias)=='string'and predicate(alias)then return true end
    end
    return false
end
local function weapon(key) return key:match('^Weapon_%d+$')or key:match('^PhantomEdges_%d+$')end
local function book(key) return key:match('^Reading_')or key:match('^ReadingDes_')or key:match('^Item_Memo_')or key:match('^Item_MemoDes_')end
local function person(key) return key:match('^Character_')or key:match('^BossName_')or key:match('^EnemyName_')end
function M.subtitle(scope,path)
    return not scope or scope.full_text or(scope.characters and (path:match('%.SpeakerText$')~=nil or path:match('%.ContentRichText[%w_]*$')~=nil))
end
function M.item(scope,entry,isTitle,isBestiary)
    if not entry then return false end
    if not scope or scope.full_text then return true end
    if scope.books and(isBestiary or entry.context=='book_body'or anyKey(entry,book))then return true end
    if isTitle and scope.characters and(isBestiary or anyKey(entry,person))then return true end
    return isTitle and scope.weapons and anyKey(entry,weapon)or false
end
function M.general(scope,entry,path)
    if not entry then return false end
    if not scope or scope.full_text then return true end
    if scope.books and(path:find('.WB_Literature.',1,true)or entry.context=='book_body'or anyKey(entry,book))then return true end
    if scope.characters and(entry.context=='hud_combatant'or anyKey(entry,person))then return true end
    return scope.weapons and anyKey(entry,weapon)or false
end
function M.literatureUI(scope,path)
    return not scope or scope.full_text or(scope.books and path:find('.WB_Literature.',1,true)~=nil)
end
function M.detail(scope,class)
    return not scope or scope.full_text or(class=='W_MemoryFlowerEntry_C'and(scope.books or scope.characters))
end
return M
