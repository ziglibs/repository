//! HTTP Client based on libcurl

const std = @import("std");
const mem = std.mem;
const cURL = @cImport({
    @cInclude("curl/curl.h");
});

const UA: []const u8 = "ziglibs/1.0.0";

pub const Client = struct {
    allocator: mem.Allocator,
    handle: *cURL.CURL,
    headers: *cURL.curl_slist,

    const Self = @This();
    const RawResponse = std.ArrayList(u8);

    pub fn deinit(self: Self) void {
        cURL.curl_slist_free_all(self.headers);
        cURL.curl_easy_cleanup(self.handle);
    }

    pub fn init(alloctor: mem.Allocator) !Self {
        const handle = cURL.curl_easy_init() orelse return error.CURLHandleInitFailed;

        var headers: ?*cURL.curl_slist = null;
        headers = cURL.curl_slist_append(headers, "Accept: application/vnd.github.v3+json");
        if (std.os.getenv("GITHUB_TOKEN")) |token| {
            var buf = std.ArrayList(u8).init(alloctor);
            try buf.appendSlice("Authorization: Bearer ");
            try buf.appendSlice(token);
            headers = cURL.curl_slist_append(headers, buf.items.ptr);
        }
        if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_HTTPHEADER, headers) != cURL.CURLE_OK)
            unreachable();

        if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEFUNCTION, writeToArrayListCallback) != cURL.CURLE_OK)
            unreachable();

        if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_USERAGENT, UA.ptr) != cURL.CURLE_OK)
            unreachable();

        if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_FOLLOWLOCATION, @as(c_long, 1)) != cURL.CURLE_OK)
            unreachable();

        return Self{ .allocator = alloctor, .handle = handle, .headers = headers orelse unreachable };
    }

    pub fn json(self: Self, comptime T: type, url: [:0]const u8) !T {
        const resp = try self.request(url);
        defer resp.deinit();

        var stream = std.json.TokenStream.init(resp.items);
        return try std.json.parse(T, &stream, .{ .allocator = self.allocator, .ignore_unknown_fields = true });
    }

    fn request(
        self: Self,
        url: [:0]const u8,
    ) !RawResponse {
        if (cURL.curl_easy_setopt(self.handle, cURL.CURLOPT_URL, url) != cURL.CURLE_OK)
            return error.CouldNotSetURL;

        var response_buffer = RawResponse.init(self.allocator);
        if (cURL.curl_easy_setopt(self.handle, cURL.CURLOPT_WRITEDATA, &response_buffer) != cURL.CURLE_OK)
            return error.CouldNotSetWriteCallback;

        if (cURL.curl_easy_perform(self.handle) != cURL.CURLE_OK)
            return error.FailedToPerformRequest;

        return response_buffer;
    }

    fn writeToArrayListCallback(data: *anyopaque, size: c_uint, nmemb: c_uint, user_data: *anyopaque) callconv(.C) c_uint {
        var buffer = @intToPtr(*std.ArrayList(u8), @ptrToInt(user_data));
        var typed_data = @intToPtr([*]u8, @ptrToInt(data));
        buffer.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
        return nmemb * size;
    }
};
